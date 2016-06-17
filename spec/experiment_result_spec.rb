require "spec_helper"
require "async_experiments/experiment_result"

RSpec.describe AsyncExperiments::ExperimentResult do
  let(:id) { SecureRandom.uuid }
  let(:name) { :test_experiment }

  let(:control_run_output) { "control output" }
  let(:control_duration) { 10.0 }

  let(:candidate_run_output) { "candidate output" }
  let(:candidate_duration) { 5.0 }

  let(:redis) { double(:redis, del: nil) }
  let(:statsd) { double(:statsd, timing: nil, increment: nil) }

  let(:control) { described_class.new(name, id, :control, redis, statsd, control_run_output, control_duration) }
  let(:candidate) { described_class.new(name, id, :candidate, redis, statsd, candidate_run_output, candidate_duration) }

  describe "#key" do
    it "builds a key from the name and ID" do
      expect(control.key).to eq("test_experiment:#{id}")
    end
  end

  describe "#store_run_output" do
    it "stores the branch's run output and duration" do
      expect(redis).to receive(:set)
        .with("experiments:#{name}:#{id}:candidate", {
          run_output: candidate_run_output,
          duration: candidate_duration,
        }.to_json)

      candidate.store_run_output
    end
  end

  describe "control#process_run_output(candidate)" do
    before do
      allow(redis).to receive(:rpush)
    end

    it "reports the control and candidate durations to statsd" do
      expect(statsd).to receive(:timing)
        .with("experiments.#{name}.control", control_duration)

      expect(statsd).to receive(:timing)
        .with("experiments.#{name}.candidate", candidate_duration)

      control.process_run_output(candidate)
    end

    it "deletes the candidate data from redis" do
      expect(redis).to receive(:del).with("experiments:#{name}:#{id}:candidate")

      control.process_run_output(candidate)
    end

    context "if there's variation between the outputs" do
      it "increments the mismatch count in statsd" do
        expect(statsd).to receive(:increment)
          .with("experiments.#{name}.mismatches")

        control.process_run_output(candidate)
      end

      it "logs the mismatch to redis" do
        expect(redis).to receive(:rpush).with(
          "experiments:#{name}:mismatches",
          [["~", "", "control output", "candidate output"]].to_json,
        )

        control.process_run_output(candidate)
      end
    end

    context "if there's no variation" do
      let(:candidate_run_output) { control_run_output }

      it "does not increment the mismatch count" do
        expect(statsd).not_to receive(:increment)
        control.process_run_output(candidate)
      end

      it "does not log the mismatch to redis" do
        expect(redis).not_to receive(:rpush)
        control.process_run_output(candidate)
      end
    end
  end

  describe ".new" do
    let(:type) { :candidate }

    context "if duration and output are provided" do
      it "uses those" do
        candidate = described_class.new(name, id, type, redis, statsd, "arbitrary output", 1.23)
        expect(candidate.run_output).to eq("arbitrary output")
        expect(candidate.duration).to eq(1.23)
      end
    end

    context "if duration and output are not provided" do
      context "and redis has the data" do
        before do
          allow(redis).to receive(:get).with("experiments:#{name}:#{id}:#{type}").and_return({
            run_output: candidate_run_output,
            duration: candidate_duration,
          }.to_json)
        end

        it "uses the redis data" do
          candidate = described_class.new(name, id, type, redis, statsd)
          expect(candidate.run_output).to eq(candidate_run_output)
          expect(candidate.duration).to eq(candidate_duration)
        end

        it "is considered available" do
          candidate = described_class.new(name, id, type, redis, statsd)
          expect(candidate.available?).to eq(true)
        end
      end

      context "but redis does not have the data" do
        before do
          allow(redis).to receive(:get).and_return("")
        end

        it "is considered unavailable" do
          missing_candidate = described_class.new(name, id, type, redis, statsd)
          expect(missing_candidate.available?).to eq(false)
        end
      end
    end
  end
end

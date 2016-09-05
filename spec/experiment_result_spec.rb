require "spec_helper"
require "async_experiments/experiment_result"

RSpec.describe AsyncExperiments::ExperimentResult do
  let(:name) { :test_name }
  let(:id) { SecureRandom.uuid }
  let(:type) { :control }
  let(:output) { "output" }
  let(:duration) { 1.0 }
  let(:redis_key) { "experiments:#{name}:#{id}:#{type}" }
  let(:statsd) do
    double(
      :statsd,
      timing: nil,
      increment: nil,
    )
  end
  let(:redis) do
    double(
      :redis,
      set: true,
      rpush: true,
      expire: true,
      del: true,
    )
  end

  subject { described_class.new(name, id, type, redis, statsd, output, duration) }

  describe "#store_run_output" do
    let(:expiry) { 10 }
    after { subject.store_run_output(expiry) }

    it "sets item in redis" do
      expect(redis).to receive(:set)
        .with(redis_key, { run_output: output, duration: duration }.to_json)
    end

    it "sets an expiry on the redis entry" do
      expect(redis).to receive(:expire)
        .with(redis_key, expiry)
    end
  end

  describe "#process_run_output" do
    let(:candidate_key) { "experiments:#{name}:#{id}:candidate" }
    let(:candidate_duration) { 5.0 }
    let(:candidate_output) { "different" }
    let(:candidate) do
      double(
        :candidate,
        run_output: candidate_output,
        duration: candidate_duration,
      )
    end
    let(:expiry) { 30 }
    after { subject.process_run_output(candidate, expiry) }

    it "stores the durations with statsd" do
      expect(statsd).to receive(:timing)
        .with("experiments.#{name}.control", duration)
      expect(statsd).to receive(:timing)
        .with("experiments.#{name}.candidate", candidate_duration)
    end

    it "deletes candidate data" do
      expect(redis).to receive(:del).with(candidate_key)
    end

    context "when candidate data is different to control data" do
      let(:candidate_output) { "different" }

      it "increments mismatch count with statsd" do
        expect(statsd).to receive(:increment).with("experiments.#{name}.mismatches")
      end

      it "adds the difference to redis" do
        expect(redis).to receive(:rpush)
          .with("experiments:#{name}:mismatches", a_kind_of(String))
      end

      it "sets the expiry in redis" do
        expect(redis).to receive(:expire)
          .with("experiments:#{name}:mismatches", expiry)
      end
    end

    context "when candidate data is the same as control data" do
      let(:candidate_output) { output }

      it "doesn't increment a mismatch with statsd" do
        expect(statsd).not_to receive(:increment)
      end

      it "doesn't add a difference to redis" do
        expect(redis).not_to receive(:rpush)
      end

      it "doesn't update mismatch result expiry" do
        expect(redis).not_to receive(:expire)
      end
    end
  end

  describe "#available?" do
    subject { described_class.new(name, id, type, redis, statsd, output, duration).available? }

    context "when instance is initialised with output and duration as nil" do
      let(:output) { nil }
      let(:duration) { nil }
      before do
        allow(redis).to receive(:get)
          .and_return(redis_data.nil? ? nil : JSON.dump(redis_data))
      end

      context "and redis has the data" do
        let(:redis_data) { { run_output: "output", duration: 1.0 } }

        it { is_expected.to be true }
      end

      context "but redis doesn't have the data" do
        let(:redis_data) { nil }

        it { is_expected.to be false }
      end
    end

    context "when instance is initialised with output and duration as values" do
      let(:output) { "output" }
      let(:duration) { 1.0 }
      it { is_expected.to be true }
    end

    context "when run_output is nil and duration is provided" do
      let(:output) { nil }
      let(:duration) { 1.0 }

      it { is_expected.to be true }
    end
  end
end

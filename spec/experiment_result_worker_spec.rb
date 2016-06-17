require "spec_helper"
require "async_experiments"
require "async_experiments/experiment_result"
require "async_experiments/experiment_result_worker"

RSpec.describe AsyncExperiments::ExperimentResultWorker do
  let(:name) { "some_experiment" }
  let(:id) { SecureRandom.uuid }

  let(:statsd) { double(:statsd) }
  let(:redis) { double(:redis) }
  let(:redis_key) { double(:redis_key) }

  let(:control_output) { "control output" }
  let(:control_duration) { 10.0 }

  let(:candidate_output) { "candidate output" }
  let(:candidate_duration) { 5.0 }

  let(:control) {
    double(:control,
      control?: true,
      candidate?: false,
      key: redis_key,
    )
  }
  let(:candidate) {
    double(:candidate,
      candidate?: true,
      control?: false,
      key: redis_key,
    )
  }

  subject { described_class.new }

  before do
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    AsyncExperiments.statsd = statsd
  end

  it "uses the 'experiments' queue" do
    Sidekiq::Testing.fake! do
      described_class.perform_async

      expect(described_class.jobs.size).to eq(1)
    end
  end

  context "if we're the candidate" do
    let(:type) { "candidate" }

    it "stores the run output and duration" do
      expect(AsyncExperiments::ExperimentResult).to receive(:new)
        .with(name, id, type.to_sym, redis, statsd, candidate_output, candidate_duration)
        .and_return(candidate)

      expect(candidate).to receive(:store_run_output)

      subject.perform(name, id, candidate_output, candidate_duration, type)
    end
  end

  context "if we're the control" do
    let(:type) { "control" }

    before do
      expect(AsyncExperiments::ExperimentResult).to receive(:new)
        .with(name, id, :control, redis, statsd, control_output, control_duration)
        .and_return(control)

      expect(AsyncExperiments::ExperimentResult).to receive(:new)
        .with(name, id, :candidate, redis, statsd)
        .and_return(candidate)
    end

    context "and the candidate is available" do
      before do
        allow(candidate).to receive(:available?).and_return(true)
      end

      it "processes the run output with the candidate" do
        expect(control).to receive(:process_run_output).with(candidate)
        subject.perform(name, id, control_output, control_duration, type)
      end
    end

    context "but the candidate is unavailable" do
      before do
        allow(candidate).to receive(:available?).and_return(false)
        allow(described_class).to receive(:perform_in)
      end

      it "does not process the run output" do
        expect(control).not_to receive(:process_run_output)
        subject.perform(name, id, control_output, control_duration, type)
      end

      it "schedules the job to run again later" do
        args = [name, id, control_output, control_duration]
        expect(described_class).to receive(:perform_in).with(5, *args, type.to_sym)
        subject.perform(*args, type)
      end
    end
  end
end

require "spec_helper"
require "async_experiments"
require "async_experiments/experiment_result"
require "async_experiments/experiment_result_control_worker"

RSpec.describe AsyncExperiments::ExperimentResultControlWorker do
  let(:name) { "some_experiment" }
  let(:id) { SecureRandom.uuid }

  let(:statsd) { double(:statsd) }
  let(:redis) { double(:redis) }
  let(:redis_key) { double(:redis_key) }

  let(:control_output) { "control output" }
  let(:control_duration) { 10.0 }

  let(:candidate_output) { "candidate output" }
  let(:candidate_duration) { 5.0 }
  let(:allowed_attempts) { 5 }

  let(:expiry) { 30 }

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
    allow(AsyncExperiments::ExperimentResult).to receive(:new)
      .with(name, id, :control, redis, statsd, control_output, control_duration)
      .and_return(control)

    allow(AsyncExperiments::ExperimentResult).to receive(:new)
      .with(name, id, :candidate, redis, statsd)
      .and_return(candidate)
  end

  it "uses the 'experiments' queue" do
    Sidekiq::Testing.fake! do
      described_class.perform_async

      expect(Sidekiq::Queues["experiments"].size).to eq(1)
    end
  end

  context "when the candidate is available" do
    before do
      allow(candidate).to receive(:available?).and_return(true)
    end

    it "processes the run output with the candidate" do
      expect(control).to receive(:process_run_output).with(candidate, expiry)
      subject.perform(name, id, control_output, control_duration, expiry)
    end
  end

  context "when the candidate is unavailable" do
    before do
      allow(candidate).to receive(:available?).and_return(false)
      allow(described_class).to receive(:perform_in)
    end

    it "does not process the run output" do
      expect(control).not_to receive(:process_run_output)
      subject.perform(name, id, control_output, control_duration, expiry)
    end

    it "schedules the job to run again later" do
      args = [name, id, control_output, control_duration, expiry, allowed_attempts]
      expect(described_class).to receive(:perform_in).with(5, *args, 2)
      subject.perform(*args)
    end

    context "and it has completed it's allowed jobs" do
      it "does not schedule the job for later" do
        args = [name, id, control_output, control_duration, expiry, allowed_attempts, allowed_attempts]
        expect(described_class).to_not receive(:perform_in)
        subject.perform(*args)
      end
    end
  end
end

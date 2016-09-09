require "spec_helper"
require "async_experiments"
require "async_experiments/experiment_result"
require "async_experiments/experiment_result_candidate_worker"

RSpec.describe AsyncExperiments::ExperimentResultCandidateWorker do
  let(:name) { "some_experiment" }
  let(:id) { SecureRandom.uuid }

  let(:statsd) { double(:statsd) }
  let(:redis) { double(:redis) }
  let(:redis_key) { double(:redis_key) }

  let(:candidate_output) { "candidate output" }
  let(:candidate_duration) { 5.0 }

  let(:candidate) {
    double(:candidate,
      candidate?: true,
      control?: false,
      key: redis_key,
    )
  }
  let(:expiry) { 10 }

  subject { described_class.new }

  before do
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    AsyncExperiments.statsd = statsd
  end

  it "uses the 'experiments' queue" do
    Sidekiq::Testing.fake! do
      described_class.perform_async

      expect(Sidekiq::Queues["experiments"].size).to eq(1)
    end
  end

  it "stores the run output and duration" do
    allow(AsyncExperiments::ExperimentResult).to receive(:new)
      .with(name, id, :candidate, redis, statsd, candidate_output, candidate_duration)
      .and_return(candidate)

    expect(candidate).to receive(:store_run_output).with(expiry)

    subject.perform(name, id, candidate_output, candidate_duration, expiry)
  end
end

require "spec_helper"
require "async_experiments"
require "async_experiments/experiment_error_worker"

RSpec.describe AsyncExperiments::ExperimentErrorWorker do
  let(:name) { "some_experiment" }
  let(:error) { "Something went wrong" }

  let(:statsd) { double(:statsd, increment: nil) }
  let(:redis) { double(:redis, rpush: nil) }

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

  it "increments the statsd error count for the experiment" do
    expect(statsd).to receive(:increment).with("experiments.#{name}.exceptions")
    subject.perform(name, error)
  end

  it "stores the exception for later reporting" do
    expect(redis).to receive(:rpush).with("experiments:#{name}:exceptions", error)
    subject.perform(name, error)
  end

  context "when redis is unavailable" do
    before do
      allow(Sidekiq).to receive(:redis).and_raise(Redis::CannotConnectError)
    end

    it "does not raise the connection error" do
      expect {
        subject.perform(name, error)
      }.not_to raise_error(Redis::CannotConnectError)
    end
  end
end

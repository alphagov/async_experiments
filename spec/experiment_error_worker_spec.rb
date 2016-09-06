require "spec_helper"
require "async_experiments"
require "async_experiments/experiment_error_worker"

RSpec.describe AsyncExperiments::ExperimentErrorWorker do
  let(:name) { "some_experiment" }
  let(:error) { "Something went wrong" }
  let(:expiry) { 30 }

  let(:statsd) { double(:statsd, increment: nil) }
  let(:redis) { double(:redis, set: nil, exists: false, expire: nil) }

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

  it "increments the statsd error count for the experiment" do
    expect(statsd).to receive(:increment).with("experiments.#{name}.exceptions")
    subject.perform(name, error, expiry)
  end

  context "when redis already has the exception stored" do
    before { allow(redis).to receive(:exists).and_return(true) }

    it "does not store the exception" do
      expect(redis).not_to receive(:set)
      subject.perform(name, error, expiry)
    end
  end

  context "when redis does not have the exception stored" do
    before { allow(redis).to receive(:exists).and_return(false) }

    it "stores the exception" do
      expect(redis).to receive(:set)
        .with(/^experiments:#{Regexp.quote(name)}:exceptions:/, error)
      subject.perform(name, error, expiry)
    end
  end

  it "sets an expiry time" do
    expect(redis).to receive(:expire)
      .with(/^experiments:#{Regexp.quote(name)}:exceptions:/, expiry)
    subject.perform(name, error, expiry)
  end
end

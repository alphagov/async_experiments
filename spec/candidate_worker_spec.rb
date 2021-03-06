require "spec_helper"
require "async_experiments/candidate_worker"
require "async_experiments/experiment_result_candidate_worker"

RSpec.describe AsyncExperiments::CandidateWorker do
  let(:name) { "some_experiment" }
  let(:id) { SecureRandom.uuid }
  let(:candidate_expiry) { 5 }
  let(:results_expiry) { 60 }
  let(:arguments) do
    {
      name: name,
      id: id,
      candidate_expiry: candidate_expiry,
      results_expiry: results_expiry,
    }
  end

  let(:run_output) { [{ some: "output" }] }

  class TestWorker < AsyncExperiments::CandidateWorker
    def perform(run_output, experiment_config)
      experiment_candidate(experiment_config) do
        Timecop.travel(Time.now + 1.5)
        run_output
      end
    end
  end

  subject { TestWorker.new }

  it "uses the 'experiments' queue" do
    Sidekiq::Testing.fake! do
      TestWorker.perform_async

      expect(TestWorker.jobs.size).to eq(1)
    end
  end


  it "returns the control run output" do
    output = subject.perform(run_output, arguments)
    expect(output).to eq(run_output)
  end

  describe "#experiment_candidate(experiment_config)" do
    it "triggers an ExperimentResultCandidateWorker with the candidate output and duration" do
      expect(AsyncExperiments::ExperimentResultCandidateWorker).to receive(:perform_async)
        .with(name, id, run_output, instance_of(Float), a_kind_of(Integer))

      subject.perform(run_output, arguments)
    end

    context "when experiment errors are being raised" do
      around do |example|
        setting = ENV["RAISE_EXPERIMENT_ERRORS"]
        ENV["RAISE_EXPERIMENT_ERRORS"] = "1"

        example.run

        ENV["RAISE_EXPERIMENT_ERRORS"] = setting
      end

      it "re-raises experiment errors" do
        allow(Time).to receive(:now).and_raise(StandardError.new("Test exception"))

        expect {
          subject.perform(run_output, arguments)
        }.to raise_error(Exception, "Test exception")
      end
    end

    context "when experiment errors are being quietly reported" do
      around do |example|
        setting = ENV["RAISE_EXPERIMENT_ERRORS"]
        ENV["RAISE_EXPERIMENT_ERRORS"] = nil

        example.run

        ENV["RAISE_EXPERIMENT_ERRORS"] = setting
      end

      it "re-raises experiment errors" do
        allow(Time).to receive(:now).and_raise(StandardError.new("Test exception"))

        expect(AsyncExperiments::ExperimentErrorWorker).to receive(:perform_async)
          .with(name, instance_of(String), a_kind_of(Integer))

        subject.perform(run_output, arguments)
      end
    end
  end
end

require "spec_helper"
require "async_experiments/experiment_control"
require "async_experiments/experiment_result_worker"

RSpec.describe AsyncExperiments::ExperimentControl do
  let(:name) { :some_experiment }
  let(:id) { double(:id) }

  let(:candidate_args) { [1, 2, 3] }
  let(:candidate_worker) { double(:candidate_worker, perform_async: nil) }
  let(:candidate_config) {
    {
      worker: candidate_worker,
      args: candidate_args,
    }
  }

  let(:run_output) { [{some: "output"}] }

  class TestClass
    include AsyncExperiments::ExperimentControl

    def call(name, run_output, candidate_config)
      experiment_control(name, candidate: candidate_config) do
        Timecop.travel(Time.now + 1.5)
        run_output
      end
    end
  end

  subject { TestClass.new }

  before do
    allow(SecureRandom).to receive(:uuid).and_return(id)
  end

  describe "#experiment_control(name, candidate: candidate_config)" do
    it "triggers an ExperimentResultWorker with the control output and duration" do
      expect(AsyncExperiments::ExperimentResultWorker).to receive(:perform_async)
        .with(name, id, run_output, instance_of(Float), :control)

      subject.call(name, run_output, candidate_config)
    end

    it "triggers the candidate worker with its arguments and the experiment config" do
      expect(candidate_worker).to receive(:perform_async)
        .with(*candidate_args,
          name: name,
          id: id,
        )

      subject.call(name, run_output, candidate_config)
    end

    it "returns the control run output" do
      output = subject.call(name, run_output, candidate_config)
      expect(output).to eq(run_output)
    end
  end
end

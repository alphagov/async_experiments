require "spec_helper"
require "json"
require "async_experiments"

RSpec.describe AsyncExperiments do
  let(:redis) do
    double(
      :redis,
      scan_each: nil,
      get: nil,
    )
  end

  before do
    allow(Sidekiq).to receive(:redis).and_yield(redis)
  end

  describe ".get_experiment_data(experiment_name)" do
    let(:name) { "some_experiment" }

    let(:experiment_result) do
      JSON.dump([
        ["-", "[1]", { same_key: 1, different_key: 2 }],
        ["+", "[2]", { same_key: 1, different_key: 3 }],
        ["+", "[3]", "Extra element"],
        ["-", "[4]", "Missing element"],
        ["~", "[5]", "Changed element"],
        ["-", "[3]", { moved_complex_object: 1 }],
        ["+", "[6]", { moved_complex_object: 1 }],
      ])
    end

    before do
      allow(redis).to receive(:scan_each).and_return([1])
      allow(redis).to receive(:get).and_return(experiment_result)
    end

    it "partitions and resorts experiment results for useful output" do
      results = described_class.get_experiment_data(name)

      expect(results).to eq([
        missing: [
          { "same_key" => 1, "different_key" => 2 },
          "Missing element",
        ],
        extra: [
          { "same_key" => 1, "different_key" => 3 },
          "Extra element",
        ],
        changed: [
          "Changed element",
        ],
      ])
    end
  end

  describe ".get_experiment_exceptions(experiment_name)" do
    let(:name) { "some_experiment" }

    let(:errors) do
      ["error 1", "error 2"]
    end

    before do
      allow(redis).to receive(:scan_each).and_return([1, 2])
      allow(redis).to receive(:get).with(1).and_return(errors[0])
      allow(redis).to receive(:get).with(2).and_return(errors[1])
    end

    it "returns a list of exceptions" do
      results = described_class.get_experiment_exceptions(name)

      expect(results).to eq(errors)
    end
  end
end

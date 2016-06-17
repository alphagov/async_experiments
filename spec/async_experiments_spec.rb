require "spec_helper"
require "json"
require "async_experiments"

RSpec.describe AsyncExperiments do
  describe ".get_experiment_data(experiment_name)" do
    let(:name) { "some_experiment" }

    let(:experiment_results) {
      [
        JSON.dump([
          ["-", "[1]", {same_key: 1, different_key: 2}],
          ["+", "[2]", {same_key: 1, different_key: 3}],
          ["+", "[3]", "Extra element"],
          ["-", "[4]", "Missing element"],
          ["~", "[5]", "Changed element"],
          ["-", "[3]", {moved_complex_object: 1}],
          ["+", "[6]", {moved_complex_object: 1}],
        ])
      ]
    }

    let(:redis) { double(:redis) }

    before do
      allow(Sidekiq).to receive(:redis).and_yield(redis)
      allow(redis).to receive(:lrange).with("experiments:#{name}:mismatches", 0, -1)
        .and_return(experiment_results)
    end

    it "partitions and resorts experiment results for useful output" do
      results = described_class.get_experiment_data(name)

      expect(results).to eq([
        missing: [
          {"same_key" => 1, "different_key" => 2},
          "Missing element",
        ],
        extra: [
          {"same_key" => 1, "different_key" => 3},
          "Extra element",
        ],
        changed: [
          "Changed element",
        ],
      ])
    end
  end
end

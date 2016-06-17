require "spec_helper"
require "async_experiments/util"

RSpec.describe AsyncExperiments::Util do
  describe ".present?(object)" do
    it "returns true unless empty or nil" do
      expect(described_class.present?("This is a test")).to eq(true)
      expect(described_class.present?([1, 2])).to eq(true)
      expect(described_class.present?({a: 1})).to eq(true)

      expect(described_class.present?(nil)).to eq(false)
      expect(described_class.present?("")).to eq(false)
      expect(described_class.present?([])).to eq(false)
      expect(described_class.present?({})).to eq(false)
    end
  end

  describe ".blank?(object)" do
    it "returns true if empty or nil" do
      expect(described_class.blank?(nil)).to eq(true)
      expect(described_class.blank?("")).to eq(true)
      expect(described_class.blank?([])).to eq(true)
      expect(described_class.blank?({})).to eq(true)

      expect(described_class.blank?("This is a test")).to eq(false)
      expect(described_class.blank?([1, 2])).to eq(false)
      expect(described_class.blank?({a: 1})).to eq(false)
      expect(described_class.blank?(5)).to eq(false)
      expect(described_class.blank?(5.5)).to eq(false)
    end
  end

  describe ".deep_symbolize_keys(hash)" do
    it "changes top level string keys to symbols" do
      symbolized_hash = described_class.deep_symbolize_keys(
        "test" => 1,
      )

      expect(symbolized_hash).to eq(
        test: 1,
      )
    end

    it "changes lower level string keys to symbols" do
      symbolized_hash = described_class.deep_symbolize_keys(
        test: {
          "test" => 1,
        },
      )

      expect(symbolized_hash).to eq(
        test: {
          test: 1,
        },
      )
    end

    it "leaves existing symbol keys alone" do
      symbolized_hash = described_class.deep_symbolize_keys(
        test: 1,
      )

      expect(symbolized_hash).to eq(
        test: 1,
      )
    end

    it "leaves other object keys alone" do
      symbolized_hash = described_class.deep_symbolize_keys(
        1 => "test",
      )

      expect(symbolized_hash).to eq(
        1 => "test",
      )
    end
  end
end

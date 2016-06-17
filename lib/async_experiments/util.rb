module AsyncExperiments
  module Util
    def self.present?(object)
      !self.blank?(object)
    end

    def self.blank?(object)
      object.nil? || (object.respond_to?(:empty?) && object.empty?)
    end

    def self.deep_symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), new_hash|
        key = key.respond_to?(:to_sym) ? key.to_sym : key
        new_hash[key] = self.deep_symbolize_keys(value)
      end
    end
  end
end

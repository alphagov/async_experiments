require "json"
require "hashdiff"
require "digest/sha2"
require "async_experiments/util"

module AsyncExperiments
  class ExperimentResult
    def initialize(name, id, type, redis, statsd, run_output = nil, duration = nil)
      @name = name
      @key = "#{name}:#{id}"
      @redis = redis
      @statsd = statsd
      @type = type
      @run_output = run_output
      @duration = duration

      if Util.blank?(duration)
        redis_data = data_from_redis

        if redis_data
          @run_output ||= redis_data.fetch(:run_output)
          @duration ||= redis_data.fetch(:duration)
        end
      end
    end

    attr_reader :key, :run_output, :duration

    def store_run_output(expiry)
      redis_key = "experiments:#{key}:#{type}"
      redis.set(redis_key, {
        run_output: run_output,
        duration: duration,
      }.to_json)
      redis.expire(redis_key, expiry)
    end

    def process_run_output(candidate, expiry)
      variation = HashDiff.diff(sort(self.run_output), sort(candidate.run_output))
      report_data(variation, candidate, expiry)
      redis.del("experiments:#{key}:candidate")
    end

    def available?
      Util.present?(duration)
    end

  protected

    attr_reader :redis, :statsd, :type, :name

  private

    def data_from_redis
      redis_data = redis.get("experiments:#{key}:#{type}")

      if Util.present?(redis_data)
        Util.deep_symbolize_keys(JSON.parse(redis_data))
      end
    end

    def report_data(variation, candidate, expiry)
      statsd.timing("experiments.#{name}.control", self.duration)
      statsd.timing("experiments.#{name}.candidate", candidate.duration)

      if variation != []
        statsd.increment("experiments.#{name}.mismatches")
        store_mismatch(variation, expiry)
      end
    end

    def store_mismatch(mismatch, expiry)
      json = JSON.dump(mismatch)
      hash = Digest::SHA2.base64digest(json)
      redis_key = "experiments:#{name}:mismatches:#{hash}"
      redis.set(redis_key, json) unless redis.exists(redis_key)
      redis.expire(redis_key, expiry)
    end

    def sort(object)
      case object
      when Array
        object.sort_by(&:object_id)
      when Hash
        object.each_with_object({}) { |(key, value), hash|
          hash[key] = sort(value)
        }
      else
        object
      end
    end
  end
end

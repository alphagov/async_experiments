require "json"
require "hashdiff"
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

      if Util.blank?(run_output) || Util.blank?(duration)
        redis_data = data_from_redis

        if redis_data
          @run_output ||= redis_data.fetch(:run_output)
          @duration ||= redis_data.fetch(:duration)
        end
      end
    end

    attr_reader :key, :run_output, :duration

    def store_run_output
      redis.set("experiments:#{key}:#{type}", {
        run_output: run_output,
        duration: duration,
      }.to_json)
    end

    def process_run_output(candidate)
      variation = HashDiff.diff(sort(self.run_output), sort(candidate.run_output))
      report_data(variation, candidate)
      redis.del("experiments:#{key}:candidate")
    end

    def control?
      type == :control
    end

    def candidate?
      type == :candidate
    end

    def available?
      Util.present?(run_output) && Util.present?(duration)
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

    def report_data(variation, candidate)
      statsd.timing("experiments.#{name}.control", self.duration)
      statsd.timing("experiments.#{name}.candidate", candidate.duration)

      if variation != []
        statsd.increment("experiments.#{name}.mismatches")
        redis.rpush("experiments:#{name}:mismatches", JSON.dump(variation))
      end
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

require "digest/sha2"

module AsyncExperiments
  class ExperimentErrorWorker
    include Sidekiq::Worker

    sidekiq_options queue: :experiments

    def perform(experiment_name, exception_string, expiry)
      Sidekiq.redis do |redis|
        AsyncExperiments.statsd.increment("experiments.#{experiment_name}.exceptions")
        hash = Digest::SHA2.base64digest(exception_string)
        redis_key = "experiments:#{experiment_name}:exceptions:#{hash}"
        redis.set(redis_key, exception_string) unless redis.exists(redis_key)
        redis.expire(redis_key, expiry)
      end
    end
  end
end

module AsyncExperiments
  class ExperimentErrorWorker
    include Sidekiq::Worker

    sidekiq_options queue: :experiments

    def perform(experiment_name, exception_string, expiry)
      Sidekiq.redis do |redis|
        AsyncExperiments.statsd.increment("experiments.#{experiment_name}.exceptions")
        redis_key = "experiments:#{experiment_name}:exceptions"
        redis.rpush(redis_key, exception_string)
        redis.expire(redis_key, expiry)
      end
    end
  end
end

module AsyncExperiments
  class ExperimentErrorWorker
    include Sidekiq::Worker

    sidekiq_options queue: :experiments

    def perform(experiment_name, exception_string)
      Sidekiq.redis do |redis|
        AsyncExperiments.statsd.increment("experiments.#{experiment_name}.exceptions")
        redis.rpush("experiments:#{experiment_name}:exceptions", exception_string)
      end
    end
  end
end

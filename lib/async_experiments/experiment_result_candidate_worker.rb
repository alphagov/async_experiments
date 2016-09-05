require "async_experiments/experiment_result"

module AsyncExperiments
  class ExperimentResultCandidateWorker
    include Sidekiq::Worker

    sidekiq_options queue: :experiments

    LOCK_TIMEOUT = 60

    def perform(name, id, run_output, duration, expiry)
      Sidekiq.redis do |redis|
        result = ExperimentResult.new(name, id, :candidate, redis, statsd, run_output, duration)
        result.store_run_output(expiry)
      end
    end

  private

    def statsd
      AsyncExperiments.statsd
    end
  end
end

require "async_experiments/experiment_result"

module AsyncExperiments
  class ExperimentResultControlWorker
    include Sidekiq::Worker

    sidekiq_options queue: :experiments

    LOCK_TIMEOUT = 60

    def perform(name, id, run_output, duration, expiry, allowed_attempts = 5, attempt = 1)
      Sidekiq.redis do |redis|
        result = ExperimentResult.new(name, id, :control, redis, statsd, run_output, duration)
        candidate = ExperimentResult.new(name, id, :candidate, redis, statsd)
        if candidate.available?
          result.process_run_output(candidate, expiry)
        elsif allowed_attempts > attempt
          self.class.perform_in(5, name, id, run_output, duration, expiry, allowed_attempts, attempt + 1)
        end
      end
    end

  private

    def statsd
      AsyncExperiments.statsd
    end
  end
end

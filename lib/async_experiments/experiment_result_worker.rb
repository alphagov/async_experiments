require "async_experiments/experiment_result"

module AsyncExperiments
  class ExperimentResultWorker
    include Sidekiq::Worker

    sidekiq_options queue: :experiments

    LOCK_TIMEOUT = 60

    def perform(name, id, run_output, duration, type)
      type = type.to_sym

      Sidekiq.redis do |redis|
        this_branch = ExperimentResult.new(name, id, type, redis, statsd, run_output, duration)

        if this_branch.control?
          candidate = ExperimentResult.new(name, id, :candidate, redis, statsd)
          if candidate.available?
            this_branch.process_run_output(candidate)
          else
            self.class.perform_in(5, name, id, run_output, duration, type)
          end
        elsif this_branch.candidate?
          this_branch.store_run_output
        end
      end
    end

  private

    def statsd
      AsyncExperiments.statsd
    end
  end
end

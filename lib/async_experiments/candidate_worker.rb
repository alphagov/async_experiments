require "async_experiments/experiment_result_candidate_worker"
require "async_experiments/experiment_error_worker"

module AsyncExperiments
  class CandidateWorker
    include Sidekiq::Worker

    sidekiq_options queue: :experiments

    def experiment_candidate(experiment_config)
      experiment = experiment_config.symbolize_keys

      start_time = Time.now
      run_output = yield
      duration = (Time.now - start_time).to_f
      ExperimentResultCandidateWorker.perform_async(experiment[:name], experiment[:id], run_output, duration, experiment[:candidate_expiry])

      run_output
    rescue StandardError => exception
      if ENV["RAISE_EXPERIMENT_ERRORS"]
        raise exception
      else
        backtrace = exception.backtrace
        backtrace.unshift(exception.inspect)
        ExperimentErrorWorker.perform_async(experiment[:name], backtrace.join("\n"), experiment[:results_expiry])
      end
    end
  end
end

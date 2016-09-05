require "async_experiments/experiment_result_control_worker"

module AsyncExperiments
  module ExperimentControl
    def experiment_control(
      name, candidate:, candidate_expiry: 60, results_expiry: 24 * 60 * 60
    )
      start_time = Time.now
      run_output = yield
      duration = (Time.now - start_time).to_f

      id = SecureRandom.uuid

      if run_output.class == Enumerator
        run_output = run_output.to_a
      end

      ExperimentResultControlWorker.perform_in(1, name, id, run_output, duration, results_expiry)

      candidate_worker = candidate.fetch(:worker)
      candidate_worker.perform_async(*candidate.fetch(:args),
        name: name,
        id: id,
        candidate_expiry: candidate_expiry,
        results_expiry: results_expiry,
      )

      run_output
    end
  end
end

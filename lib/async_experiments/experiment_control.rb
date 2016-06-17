require "async_experiments/experiment_result_worker"

module AsyncExperiments
  module ExperimentControl
    def experiment_control(name, candidate:)
      start_time = Time.now
      run_output = yield
      duration = (Time.now - start_time).to_f

      id = SecureRandom.uuid

      if run_output.class == Enumerator
        run_output = run_output.to_a
      end

      ExperimentResultWorker.perform_async(name, id, run_output, duration, :control)

      candidate_worker = candidate.fetch(:worker)
      candidate_worker.perform_async(*candidate.fetch(:args),
        name: name,
        id: id,
      )

      run_output
    end
  end
end

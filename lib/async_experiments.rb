require "json"
require "securerandom"
require "async_experiments/experiment_result_candidate_worker"
require "async_experiments/experiment_result_control_worker"


module AsyncExperiments
  def self.statsd
    @statsd
  end

  def self.statsd=(statsd)
    @statsd = statsd
  end

  def self.get_experiment_data(experiment_name)
    key_pattern = "experiments:#{experiment_name}:mismatches:*"
    mismatched_responses = redis_scan_and_retrieve(key_pattern).map do |json|
      JSON.parse(json)
    end

    mismatched_responses.map do |parsed|
      missing, other = parsed.partition { |(operator)| operator == "-" }

      extra, changed = other.partition { |(operator)| operator == "+" }

      missing_entries, extra_entries = self.fix_ordering_issues(
        missing.map(&:last),
        extra.map(&:last),
      )

      {
        missing: missing_entries,
        extra: extra_entries,
        changed: changed.map(&:last),
      }
    end
  end

  def self.get_experiment_exceptions(experiment_name)
    redis_scan_and_retrieve("experiments:#{experiment_name}:exceptions:*")
  end

  def self.redis_scan_and_retrieve(key_pattern)
    Sidekiq.redis do |redis|
      enumerator = redis.scan_each(
        match: key_pattern
      )
      retrieve = -> (key) { redis.get(key) }
      enumerator.map(&retrieve).compact
    end
  end

  def self.fix_ordering_issues(missing_entries, extra_entries)
    duplicate_entries = missing_entries & extra_entries

    missing_entries = missing_entries.reject { |entry| duplicate_entries.include?(entry) }
    extra_entries = extra_entries.reject { |entry| duplicate_entries.include?(entry) }

    [missing_entries, extra_entries]
  end
end

require "json"
require "securerandom"
require "async_experiments/experiment_result_worker"

module AsyncExperiments
  def self.statsd
    @statsd
  end

  def self.statsd=(statsd)
    @statsd = statsd
  end

  def self.get_experiment_data(experiment_name)
    mismatched_responses = Sidekiq.redis { |redis|
      redis.lrange("experiments:#{experiment_name}:mismatches", 0, -1)
    }

    mismatched_responses.map { |json|
      parsed = JSON.parse(json)

      missing, other = parsed.partition {|(operator, _, _)|
        operator == "-"
      }

      extra, changed = other.partition {|(operator, _, _)|
        operator == "+"
      }

      missing_entries, extra_entries = self.fix_ordering_issues(
        missing.map(&:last),
        extra.map(&:last),
      )

      {
        missing: missing_entries,
        extra: extra_entries,
        changed: changed.map(&:last),
      }
    }
  end

  def self.fix_ordering_issues(missing_entries, extra_entries)
    duplicate_entries = missing_entries & extra_entries

    missing_entries = missing_entries.reject { |entry| duplicate_entries.include?(entry) }
    extra_entries = extra_entries.reject { |entry| duplicate_entries.include?(entry) }

    [missing_entries, extra_entries]
  end
end

module GovukSidekiq
  module RedisRecovery
    class ClientMiddleware
      def call(worker_class, job, queue, redis_pool)
        Sidekiq.redis_info
        yield
      rescue Redis::BaseConnectionError => e
        puts "Failed to connect to Redis, job:"
        puts job
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    puts "Adding GovukSidekiq::RedisRecovery::ClientMiddleware from async_experiments"
    chain.add(GovukSidekiq::RedisRecovery::ClientMiddleware)
  end
end

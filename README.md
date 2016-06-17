# Asynchronous Experiments

Similar to GitHub Scientist, but uses Sidekiq (and its Redis connection pool)
to run control and candidate branches of experiments in parallel, storing the
output for later review.

Provides helpers to assist with rendering the output from the comparison.

## IMPORTANT NOTE ABOUT SIDEKIQ

This gem expects Sidekiq to be included, but does not list it as a gem dependency.

This is because GOV.UK uses `govuk_sidekiq`, a gem which automatically configures
our apps with some standard Sidekiq configurations.  We haven't added that to the
gemspec as other organisations may want to use other methods to configure Sidekiq.

The gem also assumes access to statsd for reporting purposes.

## Technical documentation

Example usage:
```
require "async_experiments/experiment_control"

class ContentItemsController < ApplicationController
  include AsyncExperiments::ExperimentControl

  def linkables
    candidate = {
      worker: LinkablesCandidate,
      args: [
        query_params.fetch(:document_type),
      ],
    }

    presented = experiment_control(:linkables, candidate: candidate) {
      Queries::GetContentCollection.new(
        document_type: query_params.fetch(:document_type),
        fields: %w(
          title
          content_id
          publication_state
          base_path
          internal_name
        ),
        pagination: NullPagination.new
      ).call
    }

    render json: presented
  end
end
```

```
require "async_experiments/candidate_worker"

class LinkablesCandidate < AsyncExperiments::CandidateWorker
  def perform(document_type, experiment)
    experiment_candidate(experiment) do
      Queries::GetLinkables.new(
        document_type: document_type,
      ).call
    end
  end
end
```

```
class DebugController < ApplicationController
  skip_before_action :require_signin_permission!
  before_action :validate_experiment_name, only: [:experiment]

  def experiment
    @mismatched_responses = AsyncExperiments.get_experiment_data(params[:experiment])
  end

private

  def validate_experiment_name
    raise "Experiment names don't contain `:`" if params[:experiment].include?(":")
  end
end
```

```
<ul>
  <% @mismatched_responses.each_with_index do |mismatch, i| %>
    <li>
      <ul>
        <li><a href="#missing-#{i}">Missing</a></li>
        <li><a href="#extra-#{i}">Extra</a></li>
        <li><a href="#changed-#{i}">Changed</a></li>
      </ul>

      <h3 id="missing-#{i}">Missing from candidate</h3>
      <% mismatch[:missing].each do |entry| %>
        <pre><%= PP.pp(entry, "") %></pre>
      <% end %>

      <h3 id="extra-#{i}">Extra in candidate</h3>
      <% mismatch[:extra].each do |entry| %>
        <pre><%= PP.pp(entry, "") %></pre>
      <% end %>

      <h3 id="changed-#{i}">Changed in candidate</h3>
      <% mismatch[:changed].each do |entry| %>
        <pre><%= PP.pp(entry, "") %></pre>
      <% end %>
    </li>
  <% end %>
</ul>
```

```
statsd_client = Statsd.new("localhost")
statsd_client.namespace = "govuk.app.publishing-api"
AsyncExperiments.statsd = statsd_client
```

## Licence

[MIT License](LICENCE)

## Versioning policy

See https://github.com/alphagov/styleguides/blob/master/rubygems.md#versioning

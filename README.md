# Asynchronous Experiments

This tool is used to understand the implications of replacing a section of code
(known as control) with a different piece of code (the candidate) in terms of
interchangeable outputs and effects on performance. It reports differences in
output to redis and differences in duration comparisons to statsd.

It is similar to [GitHub Scientist](https://github.com/github/scientist), but
uses Sidekiq (and its Redis connection pool) to run control and candidate branches
of experiments in parallel, storing the output for later review.

It provides helpers to assist with rendering the output from the comparison.

## IMPORTANT NOTE ABOUT SIDEKIQ

This gem expects Sidekiq to be included, but does not list it as a gem dependency.

This is because GOV.UK uses `govuk_sidekiq`, a gem which automatically configures
our apps with some standard Sidekiq configurations.  We haven't added that to the
gemspec as other organisations may want to use other methods to configure Sidekiq.

The gem also assumes access to statsd for reporting purposes.

## Technical documentation

Example usage: [experiments-framework](https://github.com/alphagov/publishing-api/tree/experiments-framework)
branch of the [Publishing API](https://github.com/alphagov/publishing-api)

### Evaluate a piece of code for replacing

- Identify the code you want to consider replacing, your control
- Include `AsyncExperiments::ExperimentControl` into the class that contains
  your control code
- `experiment_control` is passed the user defined name of the experiment,
  details of a candidate worker it can initialise and a block of the control
  code
- `experiment_control` will return the results of the control code and the
  code can proceed as before
- By default the results of the experiment will be stored in redis for 24 hours
  this can be altered by including `results_expiry: {number of seconds}` in
  the hash of `experiment_control` arguments.

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

### Run your replacement code asynchronously from a Sidekiq worker

- A candidate worker is created, which will be created automatically based on
  the arguments passed to `experiment_control`.
- The worker receives the arguments defined in the args attribute of the
  candidate, with an extra argument that is the name of the experiment.
- The name of the experiment and a block of the candidate code is passed to
  `experiment_candidate` which will monitor the duration and the response.
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

### Access the instances where the response of candidate and control didn't match

- The static method `get_experiment_data` can be called on `AsyncExperiments`
  to load an array of the cases where the responses didn't match

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
        <li><a href="#missing-<%= i %>">Missing</a></li>
        <li><a href="#extra-<%= i %>">Extra</a></li>
        <li><a href="#changed-<%= i %>">Changed</a></li>
      </ul>

      <h3 id="missing-<%= i %>">Missing from candidate</h3>
      <% mismatch[:missing].each do |entry| %>
        <pre><%= PP.pp(entry, "") %></pre>
      <% end %>

      <h3 id="extra-<%= i %>">Extra in candidate</h3>
      <% mismatch[:extra].each do |entry| %>
        <pre><%= PP.pp(entry, "") %></pre>
      <% end %>

      <h3 id="changed-<%= i %>">Changed in candidate</h3>
      <% mismatch[:changed].each do |entry| %>
        <pre><%= PP.pp(entry, "") %></pre>
      <% end %>
    </li>
  <% end %>
</ul>
```

### Make statsd available

- For a rails app this would be done in `config/initialisers`

```
statsd_client = Statsd.new("localhost")
statsd_client.namespace = "govuk.app.publishing-api"
AsyncExperiments.statsd = statsd_client
```

### Example implementation

The [experiments-framework](https://github.com/alphagov/publishing-api/tree/experiments-framework)
branch of GOV.UK [Publishing API](https://github.com/alphagov/publishing-api)
contains an implementation of this gem.

## Licence

[MIT License](LICENCE)

## Versioning policy

See https://github.com/alphagov/styleguides/blob/master/rubygems.md#versioning

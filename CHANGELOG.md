# 0.0.1

* Create a gem which provides an asynchronous experiment framework.

  Similar to GitHub Scientist, but uses Sidekiq (and its Redis connection pool)
  to run control and candidate branches of experiments in parallel, storing the
  output for later review.

  Provides helpers to assist with rendering the output from the comparison.

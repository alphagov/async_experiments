# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "async_experiments/version"
require "pathname"

Gem::Specification.new do |spec|
  spec.name          = "async_experiments"
  spec.version       = AsyncExperiments::VERSION
  spec.authors       = ["Elliot Crosby-McCullough"]
  spec.email         = ["elliot.cm@gmail.com"]
  spec.summary       = "An asynchronous experiment framework."
  spec.homepage      = "http://github.com/alphagov/async_experiments"
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*") + %w(README.md LICENCE.txt)
  spec.test_files    = Dir.glob("spec/**/*")
  spec.require_paths = ["lib"]

  spec.add_dependency "hashdiff", "~> 0"

  spec.add_development_dependency "rspec", "~> 3.4"
  spec.add_development_dependency "rake", "~> 11.2"
  spec.add_development_dependency "bundler", ">= 1.10"
  spec.add_development_dependency "gem_publisher", "1.5.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "sidekiq"
end

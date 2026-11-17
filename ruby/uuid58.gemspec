# frozen_string_literal: true

require_relative "lib/uuid58/version"

Gem::Specification.new do |spec|
  spec.name = "uuid58"
  spec.version = Uuid58::VERSION
  spec.authors = ["Nakano as a Service"]
  spec.summary = "Shorten UUIDs to 22-character Base58 strings, and back."
  spec.description = "Shorten UUIDs to 22-character Base58 strings, and back. " \
                     "URL-safe, order-preserving, and identical across languages " \
                     "under a stable, well-tested spec."
  spec.homepage = "https://nakanoasaservice.github.io/uuid58/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/nakanoasaservice/uuid58/tree/main/ruby",
    "bug_tracker_uri" => "https://github.com/nakanoasaservice/uuid58/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb"] + %w[LICENSE README.md]
  spec.require_paths = ["lib"]
end

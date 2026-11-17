# frozen_string_literal: true

require_relative "lib/uuid58/version"

Gem::Specification.new do |spec|
  spec.name = "uuid58"
  spec.version = Uuid58::VERSION
  spec.authors = ["Nakano as a Service"]
  spec.summary = "Encode UUIDs as 22-character, order-preserving Base58 strings."
  spec.description = "Converts UUIDs to and from 22-character Bitcoin Base58 strings. " \
                     "Implements the uuid58 specification and passes its test vectors."
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

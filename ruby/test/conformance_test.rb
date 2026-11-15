# frozen_string_literal: true

# Runs every applicable case in spec/vectors.json (SPEC.md Section 8).

require "json"
require "minitest/autorun"
require "uuid58"

class ConformanceTest < Minitest::Test
  VECTORS = JSON.parse(File.read(File.expand_path("../../spec/vectors.json", __dir__)))

  KIND_TO_ERROR = {
    "invalid_length" => Uuid58::InvalidLengthError,
    "invalid_character" => Uuid58::InvalidCharacterError,
    "overflow" => Uuid58::OverflowError
  }.freeze

  DECODERS = %i[decode decode_bytes decode_int].freeze

  def assert_error_kind(errors, &block)
    error = assert_raises(Uuid58::Error, &block)
    assert_kind_of ArgumentError, error
    assert_includes errors, error.kind.to_s
    # The subclass and the kind must agree.
    assert_instance_of KIND_TO_ERROR.fetch(error.kind.to_s), error
  end

  def test_metadata
    assert_equal "1.0.0", VECTORS["spec_version"]
    assert_equal Uuid58::ALPHABET, VECTORS["alphabet"]
    assert_equal Uuid58::MAX_UUID58, VECTORS["roundtrip"].map { |c| c["uuid58"] }.max
  end

  def test_roundtrip
    VECTORS["roundtrip"].each do |c|
      text = c["uuid"]
      encoded = c["uuid58"]
      hex = text.delete("-")
      raw = [hex].pack("H32")
      int = hex.to_i(16)
      msg = c["description"]

      # UUID strings (Section 5).
      assert_equal encoded, Uuid58.encode(text), msg
      assert_equal text, Uuid58.decode(encoded), msg

      # 16 bytes and integers (Section 8.1: hyphens removed, read big-endian).
      assert_equal encoded, Uuid58.encode(raw), msg
      assert_equal encoded, Uuid58.encode_bytes(raw), msg
      assert_equal encoded, Uuid58.encode(int), msg
      assert_equal encoded, Uuid58.encode_int(int), msg
      assert_equal raw, Uuid58.decode_bytes(encoded), msg
      assert_equal int, Uuid58.decode_int(encoded), msg

      # Validation (Section 6).
      assert Uuid58.valid?(encoded), msg
      assert Uuid58.uuid58?(encoded), msg
    end
  end

  def test_encode_valid
    VECTORS["encode"]["valid"].each do |c|
      assert_equal c["output"], Uuid58.encode(c["input"]), c["description"]
    end
  end

  # Cases marked "lenient" are accepted by JavaScript 1.x only; this
  # implementation is strict and MUST reject them (Section 9.1).
  def test_encode_invalid
    VECTORS["encode"]["invalid"].each do |c|
      assert_error_kind(c["errors"]) { Uuid58.encode(c["input"]) }
    end
  end

  def test_encode_invalid_bytes
    VECTORS["encode"]["invalid_bytes"].each do |c|
      raw = [c["bytes"]].pack("H*")
      assert_error_kind(c["errors"]) { Uuid58.encode(raw) }
      assert_error_kind(c["errors"]) { Uuid58.encode_bytes(raw) }
    end
  end

  def test_encode_invalid_integers
    VECTORS["encode"]["invalid_integers"].each do |c|
      int = Integer(c["integer"], 10)
      assert_error_kind(c["errors"]) { Uuid58.encode(int) }
      assert_error_kind(c["errors"]) { Uuid58.encode_int(int) }
    end
  end

  def test_decode_invalid
    VECTORS["decode"]["invalid"].each do |c|
      DECODERS.each do |decoder|
        assert_error_kind(c["errors"]) { Uuid58.public_send(decoder, c["input"]) }
      end
      refute Uuid58.valid?(c["input"]), c["description"]
    end
  end
end

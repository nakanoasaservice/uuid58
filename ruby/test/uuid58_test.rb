# frozen_string_literal: true

require "minitest/autorun"
require "securerandom"
require "uuid58"

class Uuid58Test < Minitest::Test
  UUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
  ENCODED = "XDY9dmBbcMBXqcRvYw8xJ2" # cspell:disable-line
  NON_ASCII_KINDS = %i[invalid_length invalid_character].freeze

  def assert_kind(kinds, &block)
    error = assert_raises(Uuid58::Error, &block)
    assert_includes Array(kinds), error.kind
  end

  def test_version
    assert_match(/\A\d+\.\d+\.\d+\z/, Uuid58::VERSION)
  end

  def test_basic
    assert_equal ENCODED, Uuid58.encode(UUID)
    assert_equal UUID, Uuid58.decode(ENCODED)
    assert_equal Encoding::BINARY, Uuid58.decode_bytes(ENCODED).encoding
    assert_equal 16, Uuid58.decode_bytes(ENCODED).bytesize
  end

  def test_boundaries
    assert_equal "1111111111111111111111", Uuid58.encode(0)
    assert_equal Uuid58::MAX_UUID58, Uuid58.encode(Uuid58::MAX_INT)
    assert_equal Uuid58::MAX_INT, Uuid58.decode_int(Uuid58::MAX_UUID58)
  end

  def test_error_hierarchy
    assert_operator Uuid58::Error, :<, ArgumentError
    assert_equal :invalid_length, Uuid58::InvalidLengthError.new.kind
    assert_equal :invalid_character, Uuid58::InvalidCharacterError.new.kind
    assert_equal :overflow, Uuid58::OverflowError.new.kind
  end

  def test_type_errors
    [nil, 1.0, :sym, [], true].each do |value|
      assert_raises(TypeError) { Uuid58.encode(value) }
      assert_raises(TypeError) { Uuid58.decode(value) }
      refute Uuid58.valid?(value)
    end
    assert_raises(TypeError) { Uuid58.encode_bytes(1) }
    assert_raises(TypeError) { Uuid58.encode_int("1") }
  end

  def test_binary_strings_are_raw_bytes
    raw = [UUID.delete("-")].pack("H32")
    assert_equal ENCODED, Uuid58.encode(raw)
    # A binary string is never parsed as UUID text.
    assert_kind(:invalid_length) { Uuid58.encode(UUID.b) }
    # encode_bytes takes the bytes whatever the encoding.
    assert_equal ENCODED, Uuid58.encode_bytes(raw.dup.force_encoding(Encoding::UTF_8))
  end

  def test_uuid_text_in_other_ascii_compatible_encodings
    assert_equal ENCODED, Uuid58.encode(UUID.encode(Encoding::US_ASCII))
    assert_equal ENCODED, Uuid58.encode(UUID.encode(Encoding::ISO_8859_1))
    assert_equal UUID, Uuid58.decode(ENCODED.b)
    assert Uuid58.valid?(ENCODED.b)
  end

  # Section 4.1: strings in UTF-16/UTF-32 hold the same characters.
  def test_non_ascii_compatible_encodings
    [Encoding::UTF_16LE, Encoding::UTF_16BE, Encoding::UTF_32LE].each do |enc|
      assert_equal ENCODED, Uuid58.encode(UUID.encode(enc))
      assert_equal UUID, Uuid58.decode(ENCODED.encode(enc))
      assert Uuid58.valid?(ENCODED.encode(enc))
    end
  end

  def test_lone_surrogate
    lone = "\x3D\xD8".dup.force_encoding(Encoding::UTF_16LE) # U+D83D
    decode_input = ENCODED[0, 21].encode(Encoding::UTF_16LE) + lone
    assert_kind(NON_ASCII_KINDS) { Uuid58.decode(decode_input) }
    refute Uuid58.valid?(decode_input)
    uuid_input = UUID.delete("-")[0, 31].encode(Encoding::UTF_16LE) + lone
    assert_kind(NON_ASCII_KINDS) { Uuid58.encode(uuid_input) }
  end

  # Section 8.1: inputs that are not valid Unicode, which vectors.json
  # cannot express.
  def test_ill_formed_bytes_decode
    ["\xFF", "\x80", "\xC1"].each do |bad|
      [ENCODED[0, 21] + bad, bad + ENCODED[1, 21], ENCODED[0, 10] + bad + ENCODED[11, 11]].each do |input|
        [input, input.b].each do |s|
          assert_kind(NON_ASCII_KINDS) { Uuid58.decode(s) }
          refute Uuid58.valid?(s)
        end
      end
      assert_kind(NON_ASCII_KINDS) { Uuid58.decode(ENCODED[0, 20] + bad) }
    end
  end

  def test_ill_formed_bytes_uuid_string
    ["\xFF", "\x80", "\xC1"].each do |bad|
      hyphenated = UUID[0, 35] + bad
      plain = UUID.delete("-")[0, 31] + bad
      assert_kind(NON_ASCII_KINDS) { Uuid58.encode(hyphenated) }
      assert_kind(NON_ASCII_KINDS) { Uuid58.encode(plain) }
      assert_kind(NON_ASCII_KINDS) { Uuid58.encode(UUID[0, 8] + bad + UUID[9, 27]) }
    end
  end

  def test_low_byte_is_not_mapped
    # U+0141 is "\xC5\x81" in UTF-8; neither byte may be read as "A" (0x41).
    assert_kind(NON_ASCII_KINDS) { Uuid58.decode("#{ENCODED[0, 21]}Ł") }
    assert_kind(NON_ASCII_KINDS) { Uuid58.decode("#{ENCODED[0, 20]}Ł") }
  end

  # Section 6: Ruby's ^ and $ match at line boundaries.
  def test_no_newline_tolerance
    refute Uuid58.valid?("#{ENCODED}\n")
    refute Uuid58.valid?("#{ENCODED[0, 21]}\n")
    refute Uuid58.valid?("\n#{ENCODED}")
    assert_kind(:invalid_length) { Uuid58.encode("#{UUID}\n") }
  end

  def test_overflow_vs_character_order
    # Digits overflow, but a later character is invalid (Section 4).
    assert_kind(:invalid_character) { Uuid58.decode("Zzzzzzzzzzzzzzzzzzzzz0") } # cspell:disable-line
    assert_kind(:overflow) { Uuid58.decode("Zzzzzzzzzzzzzzzzzzzzzz") } # cspell:disable-line
  end

  def test_string_to_i_leniency_is_not_inherited
    ["+4b247fd1f8745d4aa061c6fc0a8dfaf", "f4b247fd_f8745d4aa061c6fc0a8dfaf",
     " 4b247fd1f8745d4aa061c6fc0a8dfaf", "0xb247fd1f8745d4aa061c6fc0a8dfaf"].each do |input|
      assert_kind(:invalid_character) { Uuid58.encode(input) }
    end
  end

  def test_frozen_and_unfrozen_input
    assert_equal ENCODED, Uuid58.encode(+UUID)
    assert_equal UUID, Uuid58.decode(+ENCODED)
  end

  def test_order_preserving
    values = Array.new(200) { SecureRandom.random_number(Uuid58::MAX_INT + 1) }
    values += [0, 1, Uuid58::MAX_INT, 58**21 - 1, 58**21]
    assert_equal values.sort.map { |v| Uuid58.encode(v) }, values.map { |v| Uuid58.encode(v) }.sort
  end

  def test_random_roundtrip
    100.times do
      raw = SecureRandom.random_bytes(16)
      assert_equal raw, Uuid58.decode_bytes(Uuid58.encode(raw))
      uuid = SecureRandom.uuid
      assert_equal uuid, Uuid58.decode(Uuid58.encode(uuid))
    end
  end

  def test_generate
    ids = Array.new(100) { Uuid58.generate }
    ids.each do |id|
      assert Uuid58.valid?(id)
      hex = Uuid58.decode(id)
      assert_equal "4", hex[14], "version 4"
      assert_includes "89ab", hex[19], "RFC 9562 variant"
    end
    assert_equal ids.size, ids.uniq.size
  end

  def test_helpers_are_private
    refute_respond_to Uuid58, :encode_uint128
    refute_respond_to Uuid58, :parse_uuid
    refute_respond_to Uuid58, :preview
  end

  def test_error_message_is_truncated
    error = assert_raises(Uuid58::InvalidLengthError) { Uuid58.decode("a" * 10_000) }
    assert_operator error.message.length, :<, 200
    refute_includes error.message, "\n"
  end
end

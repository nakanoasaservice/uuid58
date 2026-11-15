# frozen_string_literal: true

require "securerandom"
require_relative "uuid58/version"

# Encode UUIDs as 22-character, order-preserving Base58 strings.
#
# Implements the uuid58 specification:
# https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md
#
#   Uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf") # => "XDY9dmBbcMBXqcRvYw8xJ2"
#   Uuid58.decode("XDY9dmBbcMBXqcRvYw8xJ2") # => "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
#
# Every check works on the bytes of the string, so any byte 0x80 or above
# (any non-ASCII character, or ill-formed text) is rejected, whatever the
# string's encoding claims (SPEC.md Section 4.1).
module Uuid58
  # The Bitcoin Base58 alphabet, in ascending ASCII order (SPEC.md Section 2).
  ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

  # The largest valid uuid58 string, the encoding of 2**128 - 1.
  MAX_UUID58 = "YcVfxkQb6JRzqk5kF2tNLv" # cspell:disable-line

  # The largest 128-bit value.
  MAX_INT = (1 << 128) - 1

  # Base class for every error raised for invalid input. Inspect #kind, or
  # rescue a subclass, to tell the spec error kinds (SPEC.md Section 7) apart.
  # Error messages are not part of the specification and may change.
  class Error < ArgumentError
    # The spec error kind: :invalid_length, :invalid_character or :overflow.
    def kind
      self.class::KIND
    end
  end

  # The input has the wrong length (+:invalid_length+).
  class InvalidLengthError < Error
    KIND = :invalid_length
  end

  # The input contains a character not allowed in its position
  # (+:invalid_character+).
  class InvalidCharacterError < Error
    KIND = :invalid_character
  end

  # The value is outside 0..2**128 - 1 (+:overflow+).
  class OverflowError < Error
    KIND = :overflow
  end

  ENCODED_LENGTH = 22
  private_constant :ENCODED_LENGTH

  # Byte -> digit value, nil for bytes outside the alphabet (incl. >= 0x80).
  DIGIT_VALUES = Array.new(256).tap do |table|
    ALPHABET.each_byte.with_index { |byte, i| table[byte] = i }
  end.freeze
  private_constant :DIGIT_VALUES

  HEX_DIGIT = Array.new(256, false).tap do |table|
    "0123456789abcdefABCDEF".each_byte { |byte| table[byte] = true }
  end.freeze
  private_constant :HEX_DIGIT

  HYPHEN = "-".ord
  HYPHEN_POSITIONS = [8, 13, 18, 23].freeze
  MAX_PREVIEW_LENGTH = 40
  private_constant :HYPHEN, :HYPHEN_POSITIONS, :MAX_PREVIEW_LENGTH

  module_function

  # Encodes a UUID as a 22-character uuid58 string.
  #
  # +value+ may be:
  # - a UUID string, hyphenated (+f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf+) or
  #   plain (32 hex digits), in any letter case. Nothing else is accepted: no
  #   braces, +urn:uuid:+ prefix, whitespace or misplaced hyphens;
  # - a binary string (Encoding::BINARY, e.g. from Array#pack or a +bytea+
  #   column) of exactly 16 bytes, big-endian. See #encode_bytes;
  # - an Integer in 0..2**128 - 1.
  #
  # Raises InvalidLengthError, InvalidCharacterError or OverflowError for
  # invalid input, and TypeError for any other type.
  def encode(value)
    case value
    when Integer
      encode_int(value)
    when String
      if value.encoding == Encoding::BINARY
        encode_bytes(value)
      else
        encode_uint128(parse_uuid(value))
      end
    else
      raise TypeError, "Uuid58.encode expects a String or Integer, not #{value.class}"
    end
  end

  # Encodes 16 raw bytes (big-endian) whatever the string's encoding.
  # Raises InvalidLengthError unless +bytes+ is exactly 16 bytes long.
  def encode_bytes(bytes)
    raise TypeError, "expected a String, not #{bytes.class}" unless bytes.is_a?(String)
    if bytes.bytesize != 16
      raise InvalidLengthError, "Invalid UUID bytes: expected 16 bytes, got #{bytes.bytesize}"
    end

    encode_uint128(bytes.unpack1("H32").to_i(16))
  end

  # Encodes an Integer in 0..2**128 - 1. Raises OverflowError otherwise.
  def encode_int(int)
    raise TypeError, "expected an Integer, not #{int.class}" unless int.is_a?(Integer)
    unless int.between?(0, MAX_INT)
      raise OverflowError, "Integer out of range for a 128-bit UUID: #{preview(int)}"
    end

    encode_uint128(int)
  end

  # Decodes a uuid58 string to a lowercase, hyphenated UUID string.
  #
  # Raises InvalidLengthError, InvalidCharacterError or OverflowError for
  # invalid input, and TypeError for a non-String.
  def decode(str)
    hex = decode_int(str).to_s(16).rjust(32, "0")
    "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
  end

  # Decodes a uuid58 string to 16 big-endian bytes (Encoding::BINARY).
  # Raises the same errors as #decode.
  def decode_bytes(str)
    [decode_int(str).to_s(16).rjust(32, "0")].pack("H32")
  end

  # Decodes a uuid58 string to an Integer in 0..2**128 - 1.
  # Raises the same errors as #decode.
  #
  # Checks length, then characters, then range (SPEC.md Section 4).
  def decode_int(str)
    raise TypeError, "expected a String, not #{str.class}" unless str.is_a?(String)

    str = ascii_compatible(str)
    # Length in bytes: for non-ASCII input this may report :invalid_length
    # instead of :invalid_character, which SPEC.md Section 4.1 allows.
    if str.bytesize != ENCODED_LENGTH
      raise InvalidLengthError,
            "Invalid uuid58 length: expected #{ENCODED_LENGTH} characters, " \
            "got #{str.bytesize} bytes in #{preview(str)}"
    end

    value = 0
    str.each_byte do |byte|
      digit = DIGIT_VALUES[byte]
      raise InvalidCharacterError, "Invalid uuid58 character in #{preview(str)}" if digit.nil?

      value = (value * 58) + digit
    end
    raise OverflowError, "uuid58 value exceeds 128 bits: #{preview(str)}" if value > MAX_INT

    value
  end

  # Returns true exactly when #decode would succeed on +str+. Never raises;
  # any non-String returns false.
  def valid?(str)
    # Same length and alphabet, so byte order equals numeric order
    # (SPEC.md Section 3.2) and comparing with MAX_UUID58 checks the range.
    return false unless str.is_a?(String)

    str = ascii_compatible(str)
    str.bytesize == ENCODED_LENGTH &&
      str.each_byte.all? { |byte| DIGIT_VALUES[byte] } &&
      str.b <= MAX_UUID58
  rescue Error
    false
  end

  # Generates a random (version 4) UUID and returns its uuid58 encoding.
  def generate
    encode_uint128(SecureRandom.uuid.delete("-").to_i(16))
  end

  class << self
    alias_method :uuid58?, :valid?
  end

  def encode_uint128(value)
    out = Array.new(ENCODED_LENGTH)
    (ENCODED_LENGTH - 1).downto(0) do |i|
      value, digit = value.divmod(58)
      out[i] = ALPHABET[digit]
    end
    out.join
  end

  # Parses the hyphenated or plain UUID form strictly (SPEC.md Section 5.1),
  # byte by byte. String#to_i(16) alone is not used for validation: it
  # accepts signs, underscores and trailing garbage.
  def parse_uuid(str)
    str = ascii_compatible(str)
    bytes = str.bytes
    case bytes.size
    when 36
      HYPHEN_POSITIONS.each do |pos|
        unless bytes[pos] == HYPHEN
          raise InvalidCharacterError, "Invalid UUID: expected '-' at position #{pos} in #{preview(str)}"
        end
      end
      HYPHEN_POSITIONS.reverse_each { |pos| bytes.delete_at(pos) }
    when 32
      nil
    else
      raise InvalidLengthError,
            "Invalid UUID length: expected 32 or 36 characters, got #{bytes.size} bytes in #{preview(str)}"
    end
    unless bytes.all? { |byte| HEX_DIGIT[byte] }
      raise InvalidCharacterError, "Invalid UUID: not a hexadecimal digit in #{preview(str)}"
    end

    bytes.pack("C*").to_i(16)
  end

  # Strings in an encoding that is not ASCII-compatible (UTF-16, UTF-32) are
  # transcoded to UTF-8 so their bytes can be checked like any other string.
  # Ill-formed ones (e.g. a lone surrogate) are rejected as non-ASCII.
  def ascii_compatible(str)
    return str if str.encoding.ascii_compatible?

    str.encode(Encoding::UTF_8)
  rescue EncodingError
    raise InvalidCharacterError, "Invalid character: ill-formed #{str.encoding} string"
  end

  # Formats untrusted input for an error message: truncated and inspected,
  # so huge or multi-line inputs cannot bloat or forge log lines.
  def preview(value)
    return value.inspect unless value.is_a?(String)

    text = value.b
    return text.inspect if text.bytesize <= MAX_PREVIEW_LENGTH

    "#{text.byteslice(0, MAX_PREVIEW_LENGTH).inspect}... (#{text.bytesize} bytes)"
  end

  private_class_method :encode_uint128, :parse_uuid, :ascii_compatible, :preview
end

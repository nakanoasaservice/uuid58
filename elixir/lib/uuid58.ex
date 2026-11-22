defmodule Uuid58 do
  @moduledoc """
  Shorten UUIDs to 22-character Base58 strings, and back.

  Implements the [uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md).
  The alphabet is the Bitcoin Base58 alphabet, every encoding is exactly 22
  characters, and sorting the strings byte by byte sorts the UUIDs.

      iex> Uuid58.encode!("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
      "XDY9dmBbcMBXqcRvYw8xJ2"

      iex> Uuid58.decode!("XDY9dmBbcMBXqcRvYw8xJ2")
      "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"

      iex> Uuid58.valid?("XDY9dmBbcMBXqcRvYw8xJ2")
      true

      iex> Uuid58.decode("nope")
      {:error, :invalid_length}

  `encode/1` and `decode/1` return `{:ok, value}` or `{:error, kind}`.
  The bang variants raise `Uuid58.Error`. `kind` is `:invalid_length`,
  `:invalid_character`, or `:overflow`.
  """

  @alphabet "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  @max_uuid58 "YcVfxkQb6JRzqk5kF2tNLv"
  @max_int :erlang.bsl(1, 128) - 1
  @encoded_length 22

  @base58_digits Enum.reduce(
                   Enum.with_index(:binary.bin_to_list(@alphabet)),
                   Tuple.duplicate(-1, 256),
                   fn {byte, value}, table -> put_elem(table, byte, value) end
                 )

  @hex_digits Enum.reduce(0..15, Tuple.duplicate(-1, 256), fn value, table ->
                if value < 10 do
                  put_elem(table, ?0 + value, value)
                else
                  offset = value - 10
                  table |> put_elem(?a + offset, value) |> put_elem(?A + offset, value)
                end
              end)

  @alphabet_bytes List.to_tuple(:binary.bin_to_list(@alphabet))

  @typedoc "A spec error kind."
  @type kind :: Uuid58.Error.kind()

  @doc """
  The Bitcoin Base58 alphabet. The character at position `i` (zero-based) is
  the digit with value `i`.
  """
  @spec alphabet() :: String.t()
  def alphabet, do: @alphabet

  @doc """
  The largest valid uuid58 string, the encoding of
  `ffffffff-ffff-ffff-ffff-ffffffffffff`.
  """
  @spec max_uuid58() :: String.t()
  def max_uuid58, do: @max_uuid58

  @doc "The largest 128-bit value, `2**128 - 1`."
  @spec max_integer() :: non_neg_integer()
  def max_integer, do: @max_int

  @doc """
  Encodes a UUID string or an integer in `0..2**128 - 1`.

  A UUID string is either the hyphenated form
  `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` or 32 hexadecimal digits, in any
  letter case. Braces, the `urn:uuid:` prefix, whitespace, and hyphens in
  other positions are rejected.

  A 16-byte binary is not read as raw bytes here. Pass it to `encode_bytes/1`.

  Returns `{:error, kind}` for invalid input. Raises `FunctionClauseError`
  for any other type.

  ## Examples

      iex> Uuid58.encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
      {:ok, "XDY9dmBbcMBXqcRvYw8xJ2"}

      iex> Uuid58.encode("F4B247FD1F8745D4AA061C6FC0A8DFAF")
      {:ok, "XDY9dmBbcMBXqcRvYw8xJ2"}

      iex> Uuid58.encode(0)
      {:ok, "1111111111111111111111"}

      iex> Uuid58.encode(-1)
      {:error, :overflow}

  """
  @spec encode(binary() | integer()) :: {:ok, String.t()} | {:error, kind()}
  def encode(int) when is_integer(int), do: unbang(encode_integer_result(int))
  def encode(uuid) when is_binary(uuid), do: unbang(encode_uuid_result(uuid))

  @doc """
  Like `encode/1`, but returns the uuid58 string or raises `Uuid58.Error`.
  """
  @spec encode!(binary() | integer()) :: String.t()
  def encode!(int) when is_integer(int), do: bang!(encode_integer_result(int))
  def encode!(uuid) when is_binary(uuid), do: bang!(encode_uuid_result(uuid))

  @doc """
  Encodes 16 bytes, read as an unsigned big-endian integer (RFC 9562 order,
  the same order `Ecto.UUID.dump/1` produces).

  Returns `{:error, :invalid_length}` when `bytes` is not exactly 16 bytes.

  ## Examples

      iex> raw = Base.decode16!("f4b247fd1f8745d4aa061c6fc0a8dfaf", case: :mixed)
      iex> Uuid58.encode_bytes(raw)
      {:ok, "XDY9dmBbcMBXqcRvYw8xJ2"}

      iex> Uuid58.encode_bytes(<<0>>)
      {:error, :invalid_length}

  """
  @spec encode_bytes(binary()) :: {:ok, String.t()} | {:error, :invalid_length}
  def encode_bytes(bytes) when is_binary(bytes), do: unbang(encode_bytes_result(bytes))

  @doc """
  Like `encode_bytes/1`, but returns the uuid58 string or raises `Uuid58.Error`.
  """
  @spec encode_bytes!(binary()) :: String.t()
  def encode_bytes!(bytes) when is_binary(bytes), do: bang!(encode_bytes_result(bytes))

  @doc """
  Encodes an integer in `0..2**128 - 1`.

  Returns `{:error, :overflow}` for an integer outside that range.

  ## Examples

      iex> Uuid58.encode_integer(0xF4B247FD1F8745D4AA061C6FC0A8DFAF)
      {:ok, "XDY9dmBbcMBXqcRvYw8xJ2"}

  """
  @spec encode_integer(integer()) :: {:ok, String.t()} | {:error, :overflow}
  def encode_integer(int) when is_integer(int), do: unbang(encode_integer_result(int))

  @doc """
  Like `encode_integer/1`, but returns the uuid58 string or raises `Uuid58.Error`.
  """
  @spec encode_integer!(integer()) :: String.t()
  def encode_integer!(int) when is_integer(int), do: bang!(encode_integer_result(int))

  @doc """
  Decodes a uuid58 string to the lowercase hyphenated UUID.

  The input must be exactly 22 characters from `alphabet/0`. Matching is
  case-sensitive, and whitespace is not trimmed. A value above `2**128 - 1`
  is `{:error, :overflow}`.

  Length is measured in bytes. Any non-ASCII byte is rejected.

  ## Examples

      iex> Uuid58.decode("XDY9dmBbcMBXqcRvYw8xJ2")
      {:ok, "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"}

      iex> Uuid58.decode("zzzzzzzzzzzzzzzzzzzzzz")
      {:error, :overflow}

  """
  @spec decode(binary()) :: {:ok, String.t()} | {:error, kind()}
  def decode(str) when is_binary(str), do: unbang(decode_uuid_result(str))

  @doc """
  Like `decode/1`, but returns the UUID string or raises `Uuid58.Error`.
  """
  @spec decode!(binary()) :: String.t()
  def decode!(str) when is_binary(str), do: bang!(decode_uuid_result(str))

  @doc """
  Decodes a uuid58 string to 16 big-endian bytes.

  Returns the same errors as `decode/1`.

  ## Examples

      iex> {:ok, raw} = Uuid58.decode_bytes("XDY9dmBbcMBXqcRvYw8xJ2")
      iex> Base.encode16(raw, case: :lower)
      "f4b247fd1f8745d4aa061c6fc0a8dfaf"

  """
  @spec decode_bytes(binary()) :: {:ok, <<_::128>>} | {:error, kind()}
  def decode_bytes(str) when is_binary(str), do: unbang(decode_bytes_result(str))

  @doc """
  Like `decode_bytes/1`, but returns the bytes or raises `Uuid58.Error`.
  """
  @spec decode_bytes!(binary()) :: <<_::128>>
  def decode_bytes!(str) when is_binary(str), do: bang!(decode_bytes_result(str))

  @doc """
  Decodes a uuid58 string to an integer in `0..2**128 - 1`.

  ## Examples

      iex> Uuid58.decode_integer("1111111111111111111112")
      {:ok, 1}

  """
  @spec decode_integer(binary()) :: {:ok, non_neg_integer()} | {:error, kind()}
  def decode_integer(str) when is_binary(str), do: unbang(decode_value(str))

  @doc """
  Like `decode_integer/1`, but returns the integer or raises `Uuid58.Error`.
  """
  @spec decode_integer!(binary()) :: non_neg_integer()
  def decode_integer!(str) when is_binary(str), do: bang!(decode_value(str))

  @doc """
  Returns `true` exactly when `decode/1` would succeed.

  Never raises. Any non-binary returns `false`.

  ## Examples

      iex> Uuid58.valid?("XDY9dmBbcMBXqcRvYw8xJ2")
      true

      iex> Uuid58.valid?("zzzzzzzzzzzzzzzzzzzzzz")
      false

      iex> Uuid58.valid?(nil)
      false

  """
  @spec valid?(term()) :: boolean()
  def valid?(str) when is_binary(str), do: match?({:ok, _}, decode_value(str))
  def valid?(_other), do: false

  @doc """
  Generates a random UUID version 4 and returns its uuid58 encoding.

  Uses `:crypto.strong_rand_bytes/1`.
  """
  @spec generate() :: String.t()
  def generate do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
    encode_uint128(:binary.decode_unsigned(<<a::48, 4::4, b::12, 2::2, c::62>>))
  end

  defp encode_uuid_result(uuid) do
    case parse_uuid(uuid) do
      {:ok, int} -> {:ok, encode_uint128(int)}
      error -> error
    end
  end

  defp encode_bytes_result(<<int::128>>), do: {:ok, encode_uint128(int)}

  defp encode_bytes_result(bytes) do
    {:error, :invalid_length,
     "invalid UUID bytes: expected 16 bytes, got #{byte_size(bytes)} bytes"}
  end

  defp encode_integer_result(int) when int >= 0 and int <= @max_int do
    {:ok, encode_uint128(int)}
  end

  defp encode_integer_result(_int) do
    {:error, :overflow, "integer out of range for a 128-bit UUID"}
  end

  defp decode_uuid_result(str) do
    case decode_value(str) do
      {:ok, int} -> {:ok, format_uuid(int)}
      error -> error
    end
  end

  defp decode_bytes_result(str) do
    case decode_value(str) do
      {:ok, int} -> {:ok, <<int::128>>}
      error -> error
    end
  end

  defp decode_value(str) when byte_size(str) != @encoded_length do
    {:error, :invalid_length,
     "invalid uuid58 length: expected #{@encoded_length} characters, got #{byte_size(str)} bytes"}
  end

  defp decode_value(str) do
    case accumulate(str, 0, 0) do
      {:ok, value} when value > @max_int ->
        {:error, :overflow, "uuid58 value exceeds 128 bits"}

      other ->
        other
    end
  end

  defp accumulate(<<>>, value, _pos), do: {:ok, value}

  defp accumulate(<<byte, rest::binary>>, value, pos) do
    case elem(@base58_digits, byte) do
      -1 -> {:error, :invalid_character, "invalid uuid58 character at byte #{pos}"}
      digit -> accumulate(rest, value * 58 + digit, pos + 1)
    end
  end

  defp encode_uint128(value), do: encode_digits(value, @encoded_length, [])

  defp encode_digits(_value, 0, acc), do: IO.iodata_to_binary(acc)

  defp encode_digits(value, remaining, acc) do
    encode_digits(
      div(value, 58),
      remaining - 1,
      [elem(@alphabet_bytes, rem(value, 58)) | acc]
    )
  end

  defp format_uuid(int) do
    hex =
      int
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(32, "0")

    <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
      e::binary-size(12)>> = hex

    <<a::binary-size(8), "-", b::binary-size(4), "-", c::binary-size(4), "-", d::binary-size(4),
      "-", e::binary-size(12)>>
  end

  defp parse_uuid(str) do
    case byte_size(str) do
      36 ->
        parse_hyphenated(str, 0, 0)

      32 ->
        parse_plain(str, 0, 0)

      n ->
        {:error, :invalid_length,
         "invalid UUID length: expected 32 or 36 characters, got #{n} bytes"}
    end
  end

  defp parse_hyphenated(<<>>, _pos, acc), do: {:ok, acc}

  defp parse_hyphenated(<<byte, rest::binary>>, pos, acc) do
    cond do
      hyphen_position?(pos) and byte == ?- ->
        parse_hyphenated(rest, pos + 1, acc)

      hyphen_position?(pos) ->
        {:error, :invalid_character, "invalid UUID character at byte #{pos}"}

      true ->
        case elem(@hex_digits, byte) do
          -1 -> {:error, :invalid_character, "invalid UUID character at byte #{pos}"}
          digit -> parse_hyphenated(rest, pos + 1, acc * 16 + digit)
        end
    end
  end

  defp parse_plain(<<>>, _pos, acc), do: {:ok, acc}

  defp parse_plain(<<byte, rest::binary>>, pos, acc) do
    case elem(@hex_digits, byte) do
      -1 -> {:error, :invalid_character, "invalid UUID character at byte #{pos}"}
      digit -> parse_plain(rest, pos + 1, acc * 16 + digit)
    end
  end

  defp hyphen_position?(8), do: true
  defp hyphen_position?(13), do: true
  defp hyphen_position?(18), do: true
  defp hyphen_position?(23), do: true
  defp hyphen_position?(_pos), do: false

  defp unbang({:ok, value}), do: {:ok, value}
  defp unbang({:error, kind, _message}), do: {:error, kind}

  defp bang!({:ok, value}), do: value

  defp bang!({:error, kind, message}) do
    raise Uuid58.Error, kind: kind, message: message
  end
end

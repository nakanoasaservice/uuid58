defmodule Uuid58Test do
  use ExUnit.Case, async: true

  doctest Uuid58

  @uuid "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf"
  @encoded "XDY9dmBbcMBXqcRvYw8xJ2"
  @non_ascii [:invalid_length, :invalid_character]

  test "boundaries" do
    assert Uuid58.encode!(0) == "1111111111111111111111"
    assert Uuid58.encode!(Uuid58.max_integer()) == Uuid58.max_uuid58()
    assert Uuid58.decode_integer!(Uuid58.max_uuid58()) == Uuid58.max_integer()
  end

  test "raw bytes are not uuid text" do
    raw = Base.decode16!(String.replace(@uuid, "-", ""), case: :mixed)
    assert Uuid58.encode_bytes!(raw) == @encoded
    assert {:error, :invalid_length} = Uuid58.encode(raw)
  end

  test "wrong types raise FunctionClauseError" do
    for value <- [nil, 1.0, :sym, [], true] do
      assert_raise FunctionClauseError, fn -> apply(Uuid58, :encode, [value]) end
      assert_raise FunctionClauseError, fn -> apply(Uuid58, :decode, [value]) end
      refute Uuid58.valid?(value)
    end

    assert_raise FunctionClauseError, fn -> apply(Uuid58, :encode_bytes, [1]) end
    assert_raise FunctionClauseError, fn -> apply(Uuid58, :encode_integer, ["1"]) end
  end

  test "ill-formed bytes are rejected" do
    for bad <- [<<0xFF>>, <<0x80>>, <<0xC1>>] do
      for input <- [
            binary_part(@encoded, 0, 21) <> bad,
            bad <> binary_part(@encoded, 1, 21),
            binary_part(@encoded, 0, 10) <> bad <> binary_part(@encoded, 11, 11),
            binary_part(@encoded, 0, 20) <> bad
          ] do
        assert {:error, kind} = Uuid58.decode(input)
        assert kind in @non_ascii
        refute Uuid58.valid?(input)
      end

      hyphenated = binary_part(@uuid, 0, 35) <> bad
      plain = binary_part(String.replace(@uuid, "-", ""), 0, 31) <> bad
      mixed = binary_part(@uuid, 0, 8) <> bad <> binary_part(@uuid, 9, 27)

      for input <- [hyphenated, plain, mixed] do
        assert {:error, kind} = Uuid58.encode(input)
        assert kind in @non_ascii
      end
    end
  end

  test "a non-ASCII character is not mapped to its low byte" do
    # U+0141 Ł is <<0xC5, 0x81>> in UTF-8. Neither byte is "A" (0x41).
    long = binary_part(@encoded, 0, 21) <> "Ł"
    short = binary_part(@encoded, 0, 20) <> "Ł"

    for input <- [long, short] do
      assert {:error, kind} = Uuid58.decode(input)
      assert kind in @non_ascii
      refute Uuid58.valid?(input)
    end
  end

  test "newlines are not trimmed" do
    refute Uuid58.valid?(@encoded <> "\n")
    refute Uuid58.valid?(binary_part(@encoded, 0, 21) <> "\n")
    refute Uuid58.valid?("\n" <> @encoded)
    assert {:error, :invalid_length} = Uuid58.encode(@uuid <> "\n")
  end

  test "overflow is reported only after every character is checked" do
    assert {:error, :invalid_character} = Uuid58.decode("Zzzzzzzzzzzzzzzzzzzzz0")
    assert {:error, :overflow} = Uuid58.decode("Zzzzzzzzzzzzzzzzzzzzzz")
  end

  test "integer and hex parsers are not used for validation" do
    for input <- [
          "+4b247fd1f8745d4aa061c6fc0a8dfaf",
          "f4b247fd_f8745d4aa061c6fc0a8dfaf",
          " 4b247fd1f8745d4aa061c6fc0a8dfaf",
          "0xb247fd1f8745d4aa061c6fc0a8dfaf"
        ] do
      assert {:error, :invalid_character} = Uuid58.encode(input)
    end
  end

  test "string order matches integer order" do
    random =
      Enum.map(1..200, fn _ ->
        <<int::128>> = :crypto.strong_rand_bytes(16)
        int
      end)

    values =
      [0, 1, Uuid58.max_integer(), Integer.pow(58, 21) - 1, Integer.pow(58, 21)] ++ random

    encoded = Enum.map(values, &Uuid58.encode_integer!/1)
    assert Enum.sort(encoded) == values |> Enum.sort() |> Enum.map(&Uuid58.encode_integer!/1)
  end

  test "random values round-trip" do
    for _ <- 1..100 do
      raw = :crypto.strong_rand_bytes(16)
      assert Uuid58.decode_bytes!(Uuid58.encode_bytes!(raw)) == raw

      <<int::128>> = raw
      uuid = Uuid58.decode!(Uuid58.encode!(int))
      assert Uuid58.encode!(uuid) == Uuid58.encode!(int)
      assert Uuid58.decode!(Uuid58.encode!(uuid)) == uuid
    end
  end

  test "generate returns a version 4 uuid58" do
    ids = Enum.map(1..100, fn _ -> Uuid58.generate() end)

    for id <- ids do
      assert Uuid58.valid?(id)
      uuid = Uuid58.decode!(id)
      assert String.at(uuid, 14) == "4"
      assert String.at(uuid, 19) in ~w(8 9 a b)
    end

    assert length(Enum.uniq(ids)) == length(ids)
  end

  test "error messages leave the input out" do
    err =
      assert_raise Uuid58.Error, fn ->
        Uuid58.decode!(String.duplicate("a", 10_000))
      end

    assert err.kind == :invalid_length
    refute String.contains?(err.message, "aaa")
    assert err.message == "invalid uuid58 length: expected 22 characters, got 10000 bytes"

    err =
      assert_raise Uuid58.Error, fn ->
        Uuid58.decode!(String.duplicate("1", 19) <> "\nab")
      end

    assert err.kind == :invalid_character
    assert err.message == "invalid uuid58 character at byte 19"
    refute String.contains?(err.message, "\n")

    err =
      assert_raise Uuid58.Error, fn ->
        Uuid58.encode!("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa\n")
      end

    assert err.kind == :invalid_character
    assert err.message == "invalid UUID character at byte 35"
  end
end

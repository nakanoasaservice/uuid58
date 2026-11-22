defmodule Uuid58.ConformanceTest do
  use ExUnit.Case, async: true

  # Every applicable case in spec/vectors.json (SPEC.md section 8).
  # Cases marked "lenient" are accepted by JavaScript 1.x only; this
  # implementation is strict and must reject them (section 9.1).

  @vectors Path.expand("../../spec/vectors.json", __DIR__)
           |> File.read!()
           |> Jason.decode!()

  @decoders [&Uuid58.decode/1, &Uuid58.decode_bytes/1, &Uuid58.decode_integer/1]
  @bangers [&Uuid58.decode!/1, &Uuid58.decode_bytes!/1, &Uuid58.decode_integer!/1]

  test "metadata" do
    assert @vectors["spec_version"] == "1.1.0"
    assert @vectors["alphabet"] == Uuid58.alphabet()

    max =
      @vectors["roundtrip"]
      |> Enum.map(& &1["uuid58"])
      |> Enum.max()

    assert max == Uuid58.max_uuid58()
  end

  test "roundtrip" do
    for c <- @vectors["roundtrip"] do
      uuid = c["uuid"]
      encoded = c["uuid58"]
      hex = String.replace(uuid, "-", "")
      raw = Base.decode16!(hex, case: :mixed)
      int = String.to_integer(hex, 16)
      msg = c["description"]

      assert Uuid58.encode(uuid) == {:ok, encoded}, msg
      assert Uuid58.encode!(uuid) == encoded, msg
      assert Uuid58.encode(hex) == {:ok, encoded}, msg
      assert Uuid58.decode(encoded) == {:ok, uuid}, msg
      assert Uuid58.decode!(encoded) == uuid, msg

      assert Uuid58.encode_bytes(raw) == {:ok, encoded}, msg
      assert Uuid58.encode_bytes!(raw) == encoded, msg
      assert Uuid58.encode(int) == {:ok, encoded}, msg
      assert Uuid58.encode_integer(int) == {:ok, encoded}, msg
      assert Uuid58.encode_integer!(int) == encoded, msg
      assert Uuid58.decode_bytes(encoded) == {:ok, raw}, msg
      assert Uuid58.decode_integer(encoded) == {:ok, int}, msg

      assert Uuid58.valid?(encoded), msg
    end
  end

  test "encode valid" do
    for c <- @vectors["encode"]["valid"] do
      assert Uuid58.encode(c["input"]) == {:ok, c["output"]}, c["description"]
      assert Uuid58.encode!(c["input"]) == c["output"], c["description"]
    end
  end

  test "encode invalid" do
    for c <- @vectors["encode"]["invalid"] do
      assert_kind(c["errors"], c["description"], fn -> Uuid58.encode(c["input"]) end, fn ->
        Uuid58.encode!(c["input"])
      end)
    end
  end

  test "encode invalid bytes" do
    for c <- @vectors["encode"]["invalid_bytes"] do
      raw = Base.decode16!(c["bytes"], case: :mixed)

      assert_kind(c["errors"], c["description"], fn -> Uuid58.encode_bytes(raw) end, fn ->
        Uuid58.encode_bytes!(raw)
      end)
    end
  end

  test "encode invalid integers" do
    for c <- @vectors["encode"]["invalid_integers"] do
      int = String.to_integer(c["integer"])

      assert_kind(c["errors"], c["description"], fn -> Uuid58.encode(int) end, fn ->
        Uuid58.encode!(int)
      end)

      assert_kind(c["errors"], c["description"], fn -> Uuid58.encode_integer(int) end, fn ->
        Uuid58.encode_integer!(int)
      end)
    end
  end

  test "decode invalid" do
    for c <- @vectors["decode"]["invalid"] do
      for {decode, decode!} <- Enum.zip(@decoders, @bangers) do
        assert_kind(c["errors"], c["description"], fn -> decode.(c["input"]) end, fn ->
          decode!.(c["input"])
        end)
      end

      refute Uuid58.valid?(c["input"]), c["description"]
    end
  end

  defp assert_kind(errors, msg, fun, bang) do
    assert {:error, kind} = fun.(), msg
    assert Atom.to_string(kind) in errors, msg

    err = assert_raise Uuid58.Error, bang
    assert err.kind == kind, msg
    refute String.contains?(err.message, "\n"), msg
  end
end

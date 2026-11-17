// Runs the shared test vectors in spec/vectors.json against this library
// (SPEC.md Section 8).

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Runtime.CompilerServices;
using System.Text.Json;
using Xunit;

namespace NakanoAsAService.Uuid58.Tests;

public class ConformanceTests
{
    private static readonly JsonElement Vectors = LoadVectors();

    private static JsonElement LoadVectors([CallerFilePath] string thisFile = "")
    {
        // dotnet/tests/Uuid58.Tests/ -> spec/vectors.json
        string path = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(thisFile)!, "..", "..", "..", "spec", "vectors.json"));
        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        return doc.RootElement.Clone();
    }

    private static IEnumerable<JsonElement> Cases(params string[] path)
    {
        JsonElement v = Vectors;
        foreach (string key in path)
        {
            v = v.GetProperty(key);
        }
        var cases = v.EnumerateArray().ToList();
        Assert.NotEmpty(cases);
        return cases;
    }

    private static string Str(JsonElement c, string key) => c.GetProperty(key).GetString()!;

    private static string[] Errors(JsonElement c) =>
        c.GetProperty("errors").EnumerateArray().Select(e => e.GetString()!).ToArray();

    private static void AssertFails(Action action, JsonElement c)
    {
        string[] expected = Errors(c);
        var e = Assert.Throws<Uuid58Exception>(action);
        Assert.True(expected.Contains(e.SpecName), $"expected [{string.Join(", ", expected)}], got {e.SpecName} for {c}");
    }

    private static byte[] HexToBytes(string hex)
    {
        Assert.Equal(0, hex.Length % 2);
        var bytes = new byte[hex.Length / 2];
        for (int i = 0; i < bytes.Length; i++)
        {
            bytes[i] = byte.Parse(hex.Substring(i * 2, 2), System.Globalization.NumberStyles.HexNumber);
        }
        return bytes;
    }

    // `uuid` with the hyphens removed, read as 16 big-endian bytes.
    // Independent of the library's own UUID parser.
    private static byte[] UuidBytes(string uuid) => HexToBytes(uuid.Replace("-", ""));

    [Fact]
    public void SpecVersion() => Assert.Equal("1.1.0", Vectors.GetProperty("spec_version").GetString());

    [Fact]
    public void AlphabetMatches() => Assert.Equal(Uuid58.Alphabet, Vectors.GetProperty("alphabet").GetString());

    [Fact]
    public void Roundtrip()
    {
        foreach (var c in Cases("roundtrip"))
        {
            string uuid = Str(c, "uuid");
            string id = Str(c, "uuid58");
            byte[] bytes = UuidBytes(uuid);
            ulong high = BitConverter.ToUInt64(bytes.Take(8).Reverse().ToArray(), 0);
            ulong low = BitConverter.ToUInt64(bytes.Skip(8).Reverse().ToArray(), 0);
            var integer = new BigInteger(bytes, isUnsigned: true, isBigEndian: true);
            // Guid parsed by the BCL from the canonical text, not by this library,
            // so a byte-order mistake in the Guid conversion cannot hide.
            var guid = Guid.ParseExact(uuid, "D");

            Assert.Equal(id, Uuid58.EncodeUuidString(uuid));
            Assert.Equal(id, Uuid58.Encode(bytes));
            Assert.Equal(id, Uuid58.Encode(high, low));
            Assert.Equal(id, Uuid58.Encode(integer));
            Assert.Equal(id, Uuid58.Encode(guid));

            Assert.Equal(uuid, Uuid58.Decode(id));
            Assert.Equal(bytes, Uuid58.DecodeToBytes(id));
            Guid decoded = Uuid58.DecodeToGuid(id);
            Assert.Equal(guid, decoded);
            Assert.Equal(uuid, decoded.ToString("D"));
            Assert.True(Uuid58.TryDecodeToGuid(id, out Guid tried));
            Assert.Equal(guid, tried);
            Assert.True(Uuid58.IsValid(id));
        }
    }

    [Fact]
    public void EncodeValid()
    {
        foreach (var c in Cases("encode", "valid"))
        {
            Assert.Equal(Str(c, "output"), Uuid58.EncodeUuidString(Str(c, "input")));
        }
    }

    [Fact]
    public void EncodeInvalid()
    {
        // `lenient` cases describe JavaScript 1.x only; this library rejects them.
        foreach (var c in Cases("encode", "invalid"))
        {
            AssertFails(() => Uuid58.EncodeUuidString(Str(c, "input")), c);
        }
    }

    [Fact]
    public void EncodeInvalidBytes()
    {
        foreach (var c in Cases("encode", "invalid_bytes"))
        {
            AssertFails(() => Uuid58.Encode(HexToBytes(Str(c, "bytes"))), c);
        }
    }

    [Fact]
    public void EncodeInvalidIntegers()
    {
        foreach (var c in Cases("encode", "invalid_integers"))
        {
            AssertFails(() => Uuid58.Encode(BigInteger.Parse(Str(c, "integer"))), c);
        }
    }

    [Fact]
    public void DecodeInvalid()
    {
        foreach (var c in Cases("decode", "invalid"))
        {
            string input = Str(c, "input");
            AssertFails(() => Uuid58.Decode(input), c);
            AssertFails(() => Uuid58.DecodeToBytes(input), c);
            AssertFails(() => Uuid58.DecodeToGuid(input), c);
            Assert.False(Uuid58.TryDecodeToGuid(input, out Guid g));
            Assert.Equal(Guid.Empty, g);
            Assert.False(Uuid58.IsValid(input));
        }
    }
}

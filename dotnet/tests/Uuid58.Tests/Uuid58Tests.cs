using System;
using System.Linq;
using System.Numerics;
using Xunit;

namespace NakanoAsAService.Uuid58.Tests;

public class Uuid58Tests
{
    private const string Uuid = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
    private const string Id = "XDY9dmBbcMBXqcRvYw8xJ2";

    [Fact]
    public void Constants()
    {
        Assert.Equal(58, Uuid58.Alphabet.Length);
        Assert.Equal(22, Uuid58.Length);
        Assert.Equal(Uuid58.Max, Uuid58.Encode(ulong.MaxValue, ulong.MaxValue));
        Assert.Equal(Uuid58.Alphabet, new string(Uuid58.Alphabet.OrderBy(c => c).ToArray()));
    }

    [Fact]
    public void GuidUsesRfc9562ByteOrder()
    {
        // Guid.ToByteArray() starts with fd 47 b2 f4; the spec's order starts with f4 b2 47 fd.
        var guid = new Guid(Uuid);
        Assert.Equal(Id, Uuid58.Encode(guid));
        Assert.Equal(new byte[] { 0xf4, 0xb2, 0x47, 0xfd, 0x1f, 0x87, 0x45, 0xd4 }, Uuid58.DecodeToBytes(Id).Take(8));
        Assert.Equal(guid, Uuid58.DecodeToGuid(Id));
    }

    [Fact]
    public void EncodeUuidStringAcceptsBothFormsInAnyCase()
    {
        Assert.Equal(Id, Uuid58.EncodeUuidString(Uuid));
        Assert.Equal(Id, Uuid58.EncodeUuidString(Uuid.ToUpperInvariant()));
        Assert.Equal(Id, Uuid58.EncodeUuidString(Uuid.Replace("-", "")));
        Assert.Equal(Id, Uuid58.EncodeUuidString("F4b247Fd1f8745D4aa061c6fc0a8dfaF"));
    }

    [Theory]
    [InlineData("{f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf}", Uuid58ErrorKind.InvalidLength)]
    [InlineData("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa", Uuid58ErrorKind.InvalidLength)]
    [InlineData("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa０", Uuid58ErrorKind.InvalidCharacter)]
    [InlineData("f4b247fd_1f87_45d4_aa06_1c6fc0a8dfaf", Uuid58ErrorKind.InvalidCharacter)]
    [InlineData("+4b247fd1f8745d4aa061c6fc0a8dfaf", Uuid58ErrorKind.InvalidCharacter)]
    public void EncodeUuidStringRejects(string input, Uuid58ErrorKind kind)
    {
        var e = Assert.Throws<Uuid58Exception>(() => Uuid58.EncodeUuidString(input));
        Assert.Equal(kind, e.Kind);
    }

    [Theory]
    [InlineData("XDY9dmBbcMBXqcRvYw8xJ", Uuid58ErrorKind.InvalidLength)]
    [InlineData("XDY9dmBbcMBXqcRvYw8xJ2 ", Uuid58ErrorKind.InvalidLength)]
    [InlineData("XDY9dmBbcMBXqcRvYw8xJ0", Uuid58ErrorKind.InvalidCharacter)]
    [InlineData("XDY9dmBbcMBXqcRvYw8xJŁ", Uuid58ErrorKind.InvalidCharacter)] // low byte 0x41 is 'A'
    [InlineData("XDY9dmBbcMBXqcRvYw8xJK", Uuid58ErrorKind.InvalidCharacter)] // KELVIN SIGN
    [InlineData("XDY9dmBbcMBXqcRvYw8x😀", Uuid58ErrorKind.InvalidCharacter)] // surrogate pair
    [InlineData("Zzzzzzzzzzzzzzzzzzzzz0", Uuid58ErrorKind.InvalidCharacter)]
    [InlineData("YcVfxkQb6JRzqk5kF2tNLw", Uuid58ErrorKind.Overflow)]
    [InlineData("zzzzzzzzzzzzzzzzzzzzzz", Uuid58ErrorKind.Overflow)]
    public void DecodeRejects(string input, Uuid58ErrorKind kind)
    {
        var e = Assert.Throws<Uuid58Exception>(() => Uuid58.Decode(input));
        Assert.Equal(kind, e.Kind);
        Assert.IsAssignableFrom<FormatException>(e);
        Assert.False(Uuid58.IsValid(input));
    }

    // Lone surrogates (SPEC Section 4.1). Built at runtime, because attribute
    // arguments are stored as UTF-8 and would turn them into U+FFFD.
    [Fact]
    public void RejectsLoneSurrogates()
    {
        foreach (char s in new[] { '\uD800', '\uDBFF', '\uDC00', '\uDFFF' })
        {
            string id = Id.Substring(0, 21) + s;
            Assert.Equal(Uuid58ErrorKind.InvalidCharacter, Assert.Throws<Uuid58Exception>(() => Uuid58.Decode(id)).Kind);
            Assert.False(Uuid58.IsValid(id));

            string uuid = Uuid.Substring(0, 35) + s;
            Assert.Equal(Uuid58ErrorKind.InvalidCharacter, Assert.Throws<Uuid58Exception>(() => Uuid58.EncodeUuidString(uuid)).Kind);
            string plain = s + Uuid.Replace("-", "").Substring(1);
            Assert.Equal(Uuid58ErrorKind.InvalidCharacter, Assert.Throws<Uuid58Exception>(() => Uuid58.EncodeUuidString(plain)).Kind);
        }
    }

    [Fact]
    public void Nulls()
    {
        Assert.Throws<ArgumentNullException>(() => Uuid58.Decode(null));
        Assert.Throws<ArgumentNullException>(() => Uuid58.DecodeToBytes(null));
        Assert.Throws<ArgumentNullException>(() => Uuid58.DecodeToGuid(null));
        Assert.Throws<ArgumentNullException>(() => Uuid58.EncodeUuidString(null));
        Assert.Throws<ArgumentNullException>(() => Uuid58.Encode((byte[])null));
        Assert.False(Uuid58.IsValid(null));
        Assert.False(Uuid58.TryDecodeToGuid(null, out _));
    }

    [Fact]
    public void EncodeBytesRequires16()
    {
        Assert.Equal(Uuid58ErrorKind.InvalidLength, Assert.Throws<Uuid58Exception>(() => Uuid58.Encode(new byte[15])).Kind);
        Assert.Equal(Uuid58ErrorKind.InvalidLength, Assert.Throws<Uuid58Exception>(() => Uuid58.Encode(new byte[17])).Kind);
    }

    [Fact]
    public void EncodeBigIntegerRange()
    {
        Assert.Equal("1111111111111111111111", Uuid58.Encode(BigInteger.Zero));
        Assert.Equal(Uuid58.Max, Uuid58.Encode((BigInteger.One << 128) - 1));
        Assert.Equal(Uuid58ErrorKind.Overflow, Assert.Throws<Uuid58Exception>(() => Uuid58.Encode(BigInteger.MinusOne)).Kind);
        Assert.Equal(Uuid58ErrorKind.Overflow, Assert.Throws<Uuid58Exception>(() => Uuid58.Encode(BigInteger.One << 128)).Kind);
    }

    [Fact]
    public void DecodeToBytesReturnsAFreshArray()
    {
        byte[] a = Uuid58.DecodeToBytes(Id);
        a[0] = 0;
        Assert.Equal(0xf4, Uuid58.DecodeToBytes(Id)[0]);
    }

    [Fact]
    public void RandomRoundTripAndOrdering()
    {
        var rng = new Random(58);
        var bytes = new byte[16];
        string previousId = null;
        byte[] previousBytes = null;
        for (int i = 0; i < 2000; i++)
        {
            rng.NextBytes(bytes);
            string id = Uuid58.Encode(bytes);
            Assert.Equal(22, id.Length);
            Assert.Equal(bytes, Uuid58.DecodeToBytes(id));
            var guid = Uuid58.DecodeToGuid(id);
            Assert.Equal(id, Uuid58.Encode(guid));
            Assert.Equal(guid.ToString("D"), Uuid58.Decode(id));
            if (previousId != null)
            {
                int byBytes = Math.Sign(CompareBytes(previousBytes, bytes));
                int byId = Math.Sign(string.CompareOrdinal(previousId, id));
                Assert.Equal(byBytes, byId);
            }
            previousId = id;
            previousBytes = (byte[])bytes.Clone();
        }
    }

    [Fact]
    public void GenerateProducesVersion4()
    {
        string id = Uuid58.Generate();
        Assert.True(Uuid58.IsValid(id));
        byte[] bytes = Uuid58.DecodeToBytes(id);
        Assert.Equal(0x40, bytes[6] & 0xf0);
        Assert.Equal(0x80, bytes[8] & 0xc0);
    }

    private static int CompareBytes(byte[] a, byte[] b)
    {
        for (int i = 0; i < a.Length; i++)
        {
            if (a[i] != b[i])
            {
                return a[i].CompareTo(b[i]);
            }
        }
        return 0;
    }
}

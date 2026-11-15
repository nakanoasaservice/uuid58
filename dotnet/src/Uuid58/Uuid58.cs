using System;
using System.Numerics;

namespace NakanoAsAService.Uuid58
{
    /// <summary>
    /// Encodes UUIDs as fixed-length, order-preserving 22-character Base58
    /// strings, as defined by the uuid58 specification 1.0.0.
    /// </summary>
    /// <remarks>
    /// Byte arrays are always 16 bytes in big-endian (RFC 9562) order.
    /// <see cref="Guid"/> values are converted to and from that order, not
    /// the mixed-endian order of <see cref="Guid.ToByteArray()"/>.
    /// </remarks>
    public static class Uuid58
    {
        /// <summary>The Base58 alphabet (Bitcoin), in ascending ASCII order.</summary>
        public const string Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

        /// <summary>The length of every uuid58 string.</summary>
        public const int Length = 22;

        /// <summary>The largest valid uuid58 string, the encoding of 2^128 - 1.</summary>
        public const string Max = "YcVfxkQb6JRzqk5kF2tNLv";

        private const int Base = 58;
        private const string HexDigits = "0123456789abcdef";

        // Digit value of each ASCII character, or -1 if it is not in the alphabet.
        private static readonly sbyte[] DigitValues = BuildDigitValues();

        private static readonly BigInteger MaxValue = (BigInteger.One << 128) - 1;

        private static sbyte[] BuildDigitValues()
        {
            var table = new sbyte[128];
            for (int i = 0; i < table.Length; i++)
            {
                table[i] = -1;
            }
            for (int i = 0; i < Alphabet.Length; i++)
            {
                table[Alphabet[i]] = (sbyte)i;
            }
            return table;
        }

        // ---------------------------------------------------------------- encode

        /// <summary>Encodes a 128-bit value given as its high and low 64 bits.</summary>
        public static string Encode(ulong high, ulong low)
        {
            // Four 32-bit limbs, most significant first.
            uint[] limbs = { (uint)(high >> 32), (uint)high, (uint)(low >> 32), (uint)low };
            var chars = new char[Length];
            for (int i = Length - 1; i >= 0; i--)
            {
                ulong remainder = 0;
                for (int j = 0; j < limbs.Length; j++)
                {
                    ulong cur = (remainder << 32) | limbs[j];
                    limbs[j] = (uint)(cur / Base);
                    remainder = cur % Base;
                }
                chars[i] = Alphabet[(int)remainder];
            }
            return new string(chars);
        }

        /// <summary>Encodes 16 bytes in big-endian (RFC 9562) order.</summary>
        /// <exception cref="ArgumentNullException"><paramref name="bytes"/> is null.</exception>
        /// <exception cref="Uuid58Exception">
        /// <see cref="Uuid58ErrorKind.InvalidLength"/> if <paramref name="bytes"/> is not 16 bytes long.
        /// </exception>
        public static string Encode(byte[] bytes)
        {
            if (bytes == null)
            {
                throw new ArgumentNullException(nameof(bytes));
            }
            if (bytes.Length != 16)
            {
                throw new Uuid58Exception(Uuid58ErrorKind.InvalidLength, $"expected 16 bytes, got {bytes.Length}");
            }
            return Encode(ReadUInt64BigEndian(bytes, 0), ReadUInt64BigEndian(bytes, 8));
        }

        /// <summary>Encodes a <see cref="Guid"/>, using its RFC 9562 byte order.</summary>
        public static string Encode(Guid guid) => Encode(GuidToBytes(guid));

        /// <summary>Encodes an integer in the range 0 to 2^128 - 1.</summary>
        /// <exception cref="Uuid58Exception">
        /// <see cref="Uuid58ErrorKind.Overflow"/> if <paramref name="value"/> is negative or greater than 2^128 - 1.
        /// </exception>
        public static string Encode(BigInteger value)
        {
            if (value.Sign < 0 || value > MaxValue)
            {
                throw new Uuid58Exception(Uuid58ErrorKind.Overflow, "value is outside 0..2^128 - 1");
            }
            ulong low = (ulong)(value & ulong.MaxValue);
            ulong high = (ulong)(value >> 64);
            return Encode(high, low);
        }

        /// <summary>
        /// Encodes a UUID string, either hyphenated
        /// (<c>f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf</c>) or 32 hexadecimal
        /// digits, in any letter case. Every other form is rejected.
        /// </summary>
        /// <exception cref="ArgumentNullException"><paramref name="uuid"/> is null.</exception>
        /// <exception cref="Uuid58Exception">
        /// <see cref="Uuid58ErrorKind.InvalidLength"/> or <see cref="Uuid58ErrorKind.InvalidCharacter"/>.
        /// </exception>
        public static string EncodeUuidString(string uuid) => Encode(ParseUuidString(uuid));

        // ---------------------------------------------------------------- decode

        /// <summary>Decodes a uuid58 string to 16 bytes in big-endian (RFC 9562) order.</summary>
        /// <exception cref="ArgumentNullException"><paramref name="uuid58"/> is null.</exception>
        /// <exception cref="Uuid58Exception">
        /// <see cref="Uuid58ErrorKind.InvalidLength"/>, <see cref="Uuid58ErrorKind.InvalidCharacter"/>,
        /// or <see cref="Uuid58ErrorKind.Overflow"/>.
        /// </exception>
        public static byte[] DecodeToBytes(string uuid58)
        {
            if (uuid58 == null)
            {
                throw new ArgumentNullException(nameof(uuid58));
            }
            Uuid58ErrorKind? error = TryDecodeCore(uuid58, out byte[] bytes);
            if (error.HasValue)
            {
                throw new Uuid58Exception(error.Value, Message(error.Value));
            }
            return bytes;
        }

        /// <summary>Decodes a uuid58 string to a <see cref="Guid"/>.</summary>
        /// <inheritdoc cref="DecodeToBytes(string)" path="/exception"/>
        public static Guid DecodeToGuid(string uuid58) => BytesToGuid(DecodeToBytes(uuid58));

        /// <summary>Decodes a uuid58 string to the lowercase hyphenated UUID form.</summary>
        /// <inheritdoc cref="DecodeToBytes(string)" path="/exception"/>
        public static string Decode(string uuid58) => FormatUuid(DecodeToBytes(uuid58));

        /// <summary>Decodes a uuid58 string to a <see cref="Guid"/> without throwing.</summary>
        /// <returns><c>true</c> if <paramref name="uuid58"/> is valid; otherwise <c>false</c> and <see cref="Guid.Empty"/>.</returns>
        public static bool TryDecodeToGuid(string uuid58, out Guid guid)
        {
            if (uuid58 != null && TryDecodeCore(uuid58, out byte[] bytes) == null)
            {
                guid = BytesToGuid(bytes);
                return true;
            }
            guid = Guid.Empty;
            return false;
        }

        /// <summary>
        /// Returns whether <paramref name="uuid58"/> is a valid uuid58 string:
        /// exactly 22 alphabet characters with a value of at most 2^128 - 1.
        /// Returns <c>false</c> for <c>null</c>.
        /// </summary>
        public static bool IsValid(string uuid58) => uuid58 != null && TryDecodeCore(uuid58, out _) == null;

        // -------------------------------------------------------------- generate

        /// <summary>Generates a random (version 4) UUID and returns its uuid58 encoding.</summary>
        public static string Generate() => Encode(Guid.NewGuid());

        // ------------------------------------------------------------- internals

        private static Uuid58ErrorKind? TryDecodeCore(string s, out byte[] bytes)
        {
            bytes = null;
            // Length is measured in UTF-16 code units (SPEC Section 4.1).
            if (s.Length != Length)
            {
                return Uuid58ErrorKind.InvalidLength;
            }
            // Check every character before computing the value (SPEC Section 4).
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (c >= 128 || DigitValues[c] < 0)
                {
                    return Uuid58ErrorKind.InvalidCharacter;
                }
            }
            // Four 32-bit limbs, most significant first: v = v * 58 + digit.
            var limbs = new uint[4];
            for (int i = 0; i < s.Length; i++)
            {
                ulong carry = (ulong)DigitValues[s[i]];
                for (int j = limbs.Length - 1; j >= 0; j--)
                {
                    ulong cur = (ulong)limbs[j] * Base + carry;
                    limbs[j] = (uint)cur;
                    carry = cur >> 32;
                }
                if (carry != 0)
                {
                    return Uuid58ErrorKind.Overflow;
                }
            }
            bytes = new byte[16];
            for (int j = 0; j < limbs.Length; j++)
            {
                bytes[j * 4] = (byte)(limbs[j] >> 24);
                bytes[j * 4 + 1] = (byte)(limbs[j] >> 16);
                bytes[j * 4 + 2] = (byte)(limbs[j] >> 8);
                bytes[j * 4 + 3] = (byte)limbs[j];
            }
            return null;
        }

        private static string Message(Uuid58ErrorKind kind)
        {
            switch (kind)
            {
                case Uuid58ErrorKind.InvalidLength:
                    return "uuid58 string must be exactly 22 characters";
                case Uuid58ErrorKind.InvalidCharacter:
                    return "uuid58 string contains a character outside the Base58 alphabet";
                default:
                    return "uuid58 string is greater than 2^128 - 1";
            }
        }

        private static byte[] ParseUuidString(string uuid)
        {
            if (uuid == null)
            {
                throw new ArgumentNullException(nameof(uuid));
            }
            bool hyphenated;
            if (uuid.Length == 36)
            {
                hyphenated = true;
            }
            else if (uuid.Length == 32)
            {
                hyphenated = false;
            }
            else
            {
                throw new Uuid58Exception(Uuid58ErrorKind.InvalidLength, "UUID string must be 32 or 36 characters");
            }

            var bytes = new byte[16];
            int nibble = 0;
            for (int i = 0; i < uuid.Length; i++)
            {
                char c = uuid[i];
                if (hyphenated && (i == 8 || i == 13 || i == 18 || i == 23))
                {
                    if (c != '-')
                    {
                        throw InvalidUuidCharacter();
                    }
                    continue;
                }
                int v = HexValue(c);
                if (v < 0)
                {
                    throw InvalidUuidCharacter();
                }
                bytes[nibble >> 1] |= (byte)((nibble & 1) == 0 ? v << 4 : v);
                nibble++;
            }
            return bytes;
        }

        private static Uuid58Exception InvalidUuidCharacter() =>
            new Uuid58Exception(Uuid58ErrorKind.InvalidCharacter, "UUID string contains a character not allowed in its position");

        private static int HexValue(char c)
        {
            if (c >= '0' && c <= '9')
            {
                return c - '0';
            }
            if (c >= 'a' && c <= 'f')
            {
                return c - 'a' + 10;
            }
            if (c >= 'A' && c <= 'F')
            {
                return c - 'A' + 10;
            }
            return -1;
        }

        private static string FormatUuid(byte[] bytes)
        {
            var chars = new char[36];
            int pos = 0;
            for (int i = 0; i < 16; i++)
            {
                if (i == 4 || i == 6 || i == 8 || i == 10)
                {
                    chars[pos++] = '-';
                }
                chars[pos++] = HexDigits[bytes[i] >> 4];
                chars[pos++] = HexDigits[bytes[i] & 0xf];
            }
            return new string(chars);
        }

        private static ulong ReadUInt64BigEndian(byte[] bytes, int offset)
        {
            ulong v = 0;
            for (int i = 0; i < 8; i++)
            {
                v = (v << 8) | bytes[offset + i];
            }
            return v;
        }

        // Guid.ToByteArray() and new Guid(byte[]) store the first three fields
        // (4, 2, and 2 bytes) little-endian. Reverse them to get RFC 9562 order.
        private static byte[] GuidToBytes(Guid guid)
        {
            byte[] b = guid.ToByteArray();
            SwapGuidByteOrder(b);
            return b;
        }

        private static Guid BytesToGuid(byte[] bigEndian)
        {
            var b = (byte[])bigEndian.Clone();
            SwapGuidByteOrder(b);
            return new Guid(b);
        }

        private static void SwapGuidByteOrder(byte[] b)
        {
            Array.Reverse(b, 0, 4);
            Array.Reverse(b, 4, 2);
            Array.Reverse(b, 6, 2);
        }
    }
}

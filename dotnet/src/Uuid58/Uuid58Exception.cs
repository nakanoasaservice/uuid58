using System;

namespace NakanoAsAService.Uuid58
{
    /// <summary>The error kinds of the uuid58 specification (Section 7).</summary>
    public enum Uuid58ErrorKind
    {
        /// <summary>
        /// <c>invalid_length</c>: the input has the wrong length (a uuid58
        /// string that is not 22 characters, a UUID string that is not 32 or
        /// 36 characters, or a byte array that is not 16 bytes).
        /// </summary>
        InvalidLength,

        /// <summary>
        /// <c>invalid_character</c>: the input has the right length but
        /// contains a character not allowed in its position, including any
        /// non-ASCII character.
        /// </summary>
        InvalidCharacter,

        /// <summary>
        /// <c>overflow</c>: the value is outside 0..2^128 - 1.
        /// </summary>
        Overflow,
    }

    /// <summary>Thrown when a uuid58 string, UUID string, byte array, or integer is invalid.</summary>
    public sealed class Uuid58Exception : FormatException
    {
        /// <summary>Creates an exception of the given kind.</summary>
        public Uuid58Exception(Uuid58ErrorKind kind, string message)
            : base(message)
        {
            Kind = kind;
        }

        /// <summary>The error kind, as defined by the specification.</summary>
        public Uuid58ErrorKind Kind { get; }

        /// <summary>
        /// The error kind's name in the specification, such as <c>"invalid_length"</c>.
        /// </summary>
        public string SpecName => Kind switch
        {
            Uuid58ErrorKind.InvalidLength => "invalid_length",
            Uuid58ErrorKind.InvalidCharacter => "invalid_character",
            _ => "overflow",
        };
    }
}

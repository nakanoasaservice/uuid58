/// Encode UUIDs as fixed-length, order-preserving 22-character Base58
/// strings, and back.
///
/// ```text
/// f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  <->  XDY9dmBbcMBXqcRvYw8xJ2
/// ```
///
/// This library implements the
/// [uuid58 specification](https://github.com/nakanoasaservice/uuid58/blob/main/spec/SPEC.md).
/// It works the same on the Dart VM, AOT (Flutter), and the web: all
/// arithmetic uses 32-bit words and stays below 2^53, so it never depends on
/// 64-bit integers.
library;

import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

/// The uuid58 alphabet (the Bitcoin Base58 alphabet). The character at index
/// `i` is the digit with value `i`.
const String uuid58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/// The encoding of `2^128 - 1` (`ffffffff-ffff-ffff-ffff-ffffffffffff`), the
/// largest valid uuid58 string.
const String uuid58Max = 'YcVfxkQb6JRzqk5kF2tNLv';

/// The encoding of the nil UUID (`00000000-0000-0000-0000-000000000000`).
const String uuid58Nil = '1111111111111111111111';

/// The error kinds defined by Section 7 of the specification.
enum Uuid58ErrorKind {
  /// The input has the wrong length: a uuid58 string that is not 22
  /// characters, a UUID string that is neither 32 nor 36 characters, or
  /// bytes whose length is not 16.
  invalidLength('invalid_length'),

  /// The input has the right length but contains a character that is not
  /// allowed in its position, including any non-ASCII character.
  invalidCharacter('invalid_character'),

  /// The input is a well-formed uuid58 string, but its value is greater than
  /// `2^128 - 1`.
  overflow('overflow');

  const Uuid58ErrorKind(this.code);

  /// The name of the kind in the specification, such as `invalid_length`.
  final String code;
}

/// Thrown when the input to an encode or decode function is invalid.
///
/// [kind] tells why. It implements [FormatException], so code that already
/// catches [FormatException] (as for [int.parse]) also catches this.
/// Messages are not part of the specification and may change.
class Uuid58Exception implements FormatException {
  /// Creates an exception of the given [kind].
  const Uuid58Exception(this.kind, this.message, [this.source, this.offset]);

  /// Why the input was rejected.
  final Uuid58ErrorKind kind;

  @override
  final String message;

  /// The rejected input.
  @override
  final Object? source;

  /// The index of the first rejected character, when [kind] is
  /// [Uuid58ErrorKind.invalidCharacter].
  @override
  final int? offset;

  @override
  String toString() {
    final src = source;
    final shown = src is String
        ? (src.length > 40 ? '${src.substring(0, 40)}...' : src)
        : src;
    final at = offset == null ? '' : ' at offset $offset';
    return 'Uuid58Exception(${kind.code}): $message$at'
        '${src == null ? '' : ' in "$shown"'}';
  }
}

// 2^32. Multiplying by it shifts a value left by one 32-bit word.
const int _word = 4294967296;

// 58^3. A remainder below it, shifted left by one 32-bit word, stays below
// 2^50, so long division by it is exact even in JavaScript numbers.
const int _cube = 195112;

const int _invalid = -1;

// Character code -> digit value (or _invalid), for codes 0..127.
final List<int> _base58Digits = () {
  final table = List<int>.filled(128, _invalid);
  for (var i = 0; i < 58; i++) {
    table[uuid58Alphabet.codeUnitAt(i)] = i;
  }
  return table;
}();

final List<int> _hexDigits = () {
  final table = List<int>.filled(128, _invalid);
  for (var i = 0; i < 16; i++) {
    table['0123456789abcdef'.codeUnitAt(i)] = i;
    table['0123456789ABCDEF'.codeUnitAt(i)] = i;
  }
  return table;
}();

final List<int> _alphabetCodes = uuid58Alphabet.codeUnits;
final List<int> _hexCodes = '0123456789abcdef'.codeUnits;

/// Encodes four 32-bit words (most significant first).
///
/// Each of 7 rounds long-divides the words by 58^3 and emits three digits
/// from the remainder. What is left after 21 digits is below
/// 2^128 / 58^21 < 58, the first digit.
String _encodeWords(int w0, int w1, int w2, int w3) {
  final out = List<int>.filled(22, 0);
  var pos = 21;
  for (var round = 0; round < 7; round++) {
    var q = w0 ~/ _cube;
    var rem = w0 - q * _cube;
    w0 = q;
    var cur = rem * _word + w1;
    q = cur ~/ _cube;
    rem = cur - q * _cube;
    w1 = q;
    cur = rem * _word + w2;
    q = cur ~/ _cube;
    rem = cur - q * _cube;
    w2 = q;
    cur = rem * _word + w3;
    q = cur ~/ _cube;
    rem = cur - q * _cube;
    w3 = q;
    for (var n = 0; n < 3; n++) {
      final next = rem ~/ 58;
      out[pos--] = _alphabetCodes[rem - next * 58];
      rem = next;
    }
  }
  out[0] = _alphabetCodes[w3];
  return String.fromCharCodes(out);
}

int _hexWord(String s, int start, int end, int acc) {
  for (var i = start; i < end; i++) {
    final code = s.codeUnitAt(i);
    final digit = code < 128 ? _hexDigits[code] : _invalid;
    if (digit < 0) return _invalid;
    acc = acc * 16 + digit;
  }
  return acc;
}

/// Encodes a UUID string.
///
/// Accepts exactly two forms, in any letter case: the hyphenated form
/// `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (36 characters) and 32 hexadecimal
/// digits. Braces, `urn:uuid:`, whitespace, and hyphens in other positions
/// are rejected.
///
/// ```dart
/// uuid58Encode('f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'); // 'XDY9dmBbcMBXqcRvYw8xJ2'
/// ```
///
/// Throws a [Uuid58Exception] with kind [Uuid58ErrorKind.invalidLength] or
/// [Uuid58ErrorKind.invalidCharacter].
String uuid58Encode(String uuid) {
  int w0, w1, w2, w3;
  var hyphensValid = true;
  if (uuid.length == 32) {
    w0 = _hexWord(uuid, 0, 8, 0);
    w1 = _hexWord(uuid, 8, 16, 0);
    w2 = _hexWord(uuid, 16, 24, 0);
    w3 = _hexWord(uuid, 24, 32, 0);
  } else if (uuid.length == 36) {
    hyphensValid = uuid.codeUnitAt(8) == 0x2d &&
        uuid.codeUnitAt(13) == 0x2d &&
        uuid.codeUnitAt(18) == 0x2d &&
        uuid.codeUnitAt(23) == 0x2d;
    w0 = _hexWord(uuid, 0, 8, 0);
    w1 = _hexWord(uuid, 9, 13, 0);
    if (w1 >= 0) w1 = _hexWord(uuid, 14, 18, w1);
    w2 = _hexWord(uuid, 19, 23, 0);
    if (w2 >= 0) w2 = _hexWord(uuid, 24, 28, w2);
    w3 = _hexWord(uuid, 28, 36, 0);
  } else {
    throw Uuid58Exception(
      Uuid58ErrorKind.invalidLength,
      'UUID must be 32 or 36 characters long, got ${uuid.length}',
      uuid,
    );
  }
  if (!hyphensValid || w0 < 0 || w1 < 0 || w2 < 0 || w3 < 0) {
    throw Uuid58Exception(
      Uuid58ErrorKind.invalidCharacter,
      uuid.length == 32
          ? 'UUID must be 32 hexadecimal digits'
          : 'UUID must be in the form xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
      uuid,
    );
  }
  return _encodeWords(w0, w1, w2, w3);
}

int _byteWord(Uint8List b, int i) =>
    ((b[i] * 256 + b[i + 1]) * 256 + b[i + 2]) * 256 + b[i + 3];

/// Encodes 16 bytes, read as a big-endian unsigned 128-bit integer (the byte
/// order of RFC 9562, as in `UuidValue.toBytes()` from `package:uuid`).
///
/// Throws a [Uuid58Exception] with kind [Uuid58ErrorKind.invalidLength] if
/// [bytes] is not exactly 16 bytes long.
String uuid58EncodeBytes(Uint8List bytes) {
  if (bytes.length != 16) {
    throw Uuid58Exception(
      Uuid58ErrorKind.invalidLength,
      'expected 16 bytes, got ${bytes.length}',
    );
  }
  return _encodeWords(
    _byteWord(bytes, 0),
    _byteWord(bytes, 4),
    _byteWord(bytes, 8),
    _byteWord(bytes, 12),
  );
}

/// Index of the first character of [s] that is not in the alphabet, or -1.
int _firstInvalid(String s) {
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    if (code >= 128 || _base58Digits[code] < 0) return i;
  }
  return -1;
}

/// Decodes [s] into four 32-bit words (most significant first).
List<int> _decodeWords(String s) {
  if (s.length != 22) {
    throw Uuid58Exception(
      Uuid58ErrorKind.invalidLength,
      'uuid58 string must be 22 characters long, got ${s.length}',
      s,
    );
  }
  final bad = _firstInvalid(s);
  if (bad >= 0) {
    throw Uuid58Exception(
      Uuid58ErrorKind.invalidCharacter,
      'invalid Base58 character',
      s,
      bad,
    );
  }
  // Same length and ASCII only, so code-unit order is numeric order
  // (SPEC.md Section 3.2).
  if (s.compareTo(uuid58Max) > 0) {
    throw Uuid58Exception(
      Uuid58ErrorKind.overflow,
      'value exceeds 128 bits',
      s,
    );
  }
  // The first digit, then 7 groups of 3 digits: w = w * 58^3 + group.
  // Each step stays below 2^32 * 58^3 + 2^32 < 2^50.
  var w0 = 0, w1 = 0, w2 = 0;
  var w3 = _base58Digits[s.codeUnitAt(0)];
  for (var i = 1; i < 22; i += 3) {
    final group = (_base58Digits[s.codeUnitAt(i)] * 58 +
                _base58Digits[s.codeUnitAt(i + 1)]) *
            58 +
        _base58Digits[s.codeUnitAt(i + 2)];
    var cur = w3 * _cube + group;
    var carry = cur ~/ _word;
    w3 = cur - carry * _word;
    cur = w2 * _cube + carry;
    carry = cur ~/ _word;
    w2 = cur - carry * _word;
    cur = w1 * _cube + carry;
    carry = cur ~/ _word;
    w1 = cur - carry * _word;
    // Cannot exceed 2^32 - 1: the value was checked against uuid58Max.
    w0 = w0 * _cube + carry;
  }
  return [w0, w1, w2, w3];
}

/// Decodes a uuid58 string to the lowercase hyphenated UUID string.
///
/// ```dart
/// uuid58Decode('XDY9dmBbcMBXqcRvYw8xJ2'); // 'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf'
/// ```
///
/// The input must be exactly 22 characters from [uuid58Alphabet]
/// (case-sensitive, nothing trimmed) and at most [uuid58Max].
///
/// Throws a [Uuid58Exception] with kind [Uuid58ErrorKind.invalidLength],
/// [Uuid58ErrorKind.invalidCharacter], or [Uuid58ErrorKind.overflow].
String uuid58Decode(String uuid58) {
  final words = _decodeWords(uuid58);
  final out = List<int>.filled(36, 0x2d);
  var pos = 35;
  for (var w = 3; w >= 0; w--) {
    var v = words[w];
    for (var n = 0; n < 8; n++) {
      if (pos == 8 || pos == 13 || pos == 18 || pos == 23) pos--;
      final next = v ~/ 16;
      out[pos--] = _hexCodes[v - next * 16];
      v = next;
    }
  }
  return String.fromCharCodes(out);
}

/// Decodes a uuid58 string to 16 bytes in big-endian order (the byte order
/// of RFC 9562, as taken by `UuidValue.fromByteList()` from `package:uuid`).
///
/// Throws a [Uuid58Exception] like [uuid58Decode].
Uint8List uuid58DecodeBytes(String uuid58) {
  final words = _decodeWords(uuid58);
  final out = Uint8List(16);
  for (var w = 0; w < 4; w++) {
    var v = words[w];
    for (var n = 3; n >= 0; n--) {
      final next = v ~/ 256;
      out[w * 4 + n] = v - next * 256;
      v = next;
    }
  }
  return out;
}

/// Whether [uuid58] is a valid uuid58 string: exactly 22 characters from
/// [uuid58Alphabet] with a value that fits in 128 bits.
///
/// Returns `true` exactly when [uuid58Decode] would succeed. Never throws.
bool isUuid58(String uuid58) =>
    uuid58.length == 22 &&
    _firstInvalid(uuid58) < 0 &&
    uuid58.compareTo(uuid58Max) <= 0;

/// Generates a random UUID version 4 and returns its uuid58 encoding.
///
/// Uses [Random.secure] unless [random] is given.
///
/// ```dart
/// final id = uuid58(); // e.g. 'Tj5D5H2Bc1LcPjwNNhH4xS'
/// ```
String uuid58({Random? random}) {
  final r = random ?? _secure;
  int next() => r.nextInt(65536) * 65536 + r.nextInt(65536);
  final w0 = next();
  var w1 = next();
  var w2 = next();
  final w3 = next();
  // Version 4: the high nibble of byte 6 (bits 12..15 of word 1).
  final low16 = w1 % 65536;
  w1 = w1 - low16 + 0x4000 + low16 % 0x1000;
  // Variant 10: the top two bits of byte 8 (bits 30..31 of word 2).
  w2 = w2 % 0x40000000 + 0x80000000;
  return _encodeWords(w0, w1, w2, w3);
}

final Random _secure = Random.secure();

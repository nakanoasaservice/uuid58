import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uuid58/uuid58.dart';

final _b58 = BigInt.from(58);

/// Reference encoder: plain BigInt arithmetic, as in the spec's definition.
String referenceEncode(Uint8List bytes) {
  var v = BigInt.zero;
  for (final b in bytes) {
    v = (v << 8) | BigInt.from(b);
  }
  final digits = List.filled(22, '1');
  for (var i = 21; i >= 0; i--) {
    digits[i] = uuid58Alphabet[(v % _b58).toInt()];
    v = v ~/ _b58;
  }
  return digits.join();
}

String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String hyphenate(String h) => '${h.substring(0, 8)}-${h.substring(8, 12)}-'
    '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';

Uint8List randomBytes(Random r) =>
    Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));

void main() {
  test('constants', () {
    expect(uuid58Alphabet.length, 58);
    expect(uuid58Encode('ffffffff-ffff-ffff-ffff-ffffffffffff'), uuid58Max);
    expect(uuid58Encode('00000000000000000000000000000000'), uuid58Nil);
  });

  // Also proves that the 32-bit word arithmetic is exact when compiled to
  // JavaScript, where integers are doubles.
  test('matches a BigInt reference for random and edge values', () {
    final r = Random(58);
    final inputs = [
      for (var i = 0; i < 2000; i++) randomBytes(r),
      // Every byte value at every position, others zero or 0xff.
      for (final fill in [0x00, 0xff])
        for (var pos = 0; pos < 16; pos++)
          for (final b in [0x00, 0x01, 0x7f, 0x80, 0xfe, 0xff])
            Uint8List(16)
              ..fillRange(0, 16, fill)
              ..[pos] = b,
    ];
    for (final bytes in inputs) {
      final id = referenceEncode(bytes);
      final h = hex(bytes);
      expect(uuid58EncodeBytes(bytes), id, reason: h);
      expect(uuid58Encode(h), id, reason: h);
      expect(uuid58Encode(hyphenate(h).toUpperCase()), id, reason: h);
      expect(uuid58Decode(id), hyphenate(h), reason: h);
      expect(uuid58DecodeBytes(id), bytes, reason: h);
      expect(isUuid58(id), isTrue, reason: h);
    }
  });

  test('preserves order', () {
    final r = Random(1);
    for (var i = 0; i < 500; i++) {
      final a = randomBytes(r);
      final b = randomBytes(r);
      expect(
        uuid58EncodeBytes(a).compareTo(uuid58EncodeBytes(b)).sign,
        hex(a).compareTo(hex(b)).sign,
      );
    }
  });

  group('uuid58()', () {
    test('returns a valid UUIDv4', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        final id = uuid58();
        expect(isUuid58(id), isTrue, reason: id);
        final bytes = uuid58DecodeBytes(id);
        expect(bytes[6] >> 4, 4, reason: id);
        expect(bytes[8] >> 6, 2, reason: id);
        seen.add(id);
      }
      expect(seen, hasLength(1000));
      // dart2js's Random.secure() cannot reach Node's `crypto` under the
      // test runner; real browsers (`-p chrome`) are covered.
    }, testOn: '!node');

    test('uses the given Random', () {
      expect(uuid58(random: Random(7)), uuid58(random: Random(7)));
    });
  });

  group('Uuid58Exception', () {
    test('carries kind, source and offset', () {
      try {
        uuid58Decode('XDY9dmBbcMBXqcRvY0w8xJ');
        fail('should throw');
      } on Uuid58Exception catch (e) {
        expect(e.kind, Uuid58ErrorKind.invalidCharacter);
        expect(e.kind.code, 'invalid_character');
        expect(e.source, 'XDY9dmBbcMBXqcRvY0w8xJ');
        expect(e.offset, 17);
        expect(e.toString(), contains('invalid_character'));
        expect(e.toString(), contains('offset 17'));
        expect(e.toString(), isNot(contains('XDY9')));
      }
    });

    test('is a FormatException', () {
      expect(() => uuid58Decode('nope'), throwsFormatException);
      expect(() => uuid58Encode('nope'), throwsFormatException);
      expect(() => uuid58EncodeBytes(Uint8List(15)), throwsFormatException);
    });

    test('reports overflow', () {
      expect(
        () => uuid58Decode('YcVfxkQb6JRzqk5kF2tNLw'),
        throwsA(
          isA<Uuid58Exception>().having(
            (e) => e.kind,
            'kind',
            Uuid58ErrorKind.overflow,
          ),
        ),
      );
    });

    test('kind codes match the spec', () {
      expect(Uuid58ErrorKind.values.map((k) => k.code), [
        'invalid_length',
        'invalid_character',
        'overflow',
      ]);
    });
  });
}

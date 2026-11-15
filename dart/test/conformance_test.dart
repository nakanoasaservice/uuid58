// Runs every applicable case in spec/vectors.json (SPEC.md Section 8), plus
// the inputs of Section 4.1 that JSON cannot express (lone surrogates).
//
// Browsers cannot read the vectors file; run on the VM and Node.js.
@TestOn('!browser')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uuid58/uuid58.dart';

import 'src/vectors.dart';

/// Matches a [Uuid58Exception] whose kind is one of [codes].
Matcher throwsKind(List<Object?> codes) => throwsA(
      isA<Uuid58Exception>().having((e) => e.kind.code, 'kind', isIn(codes)),
    );

/// 16 bytes read from hexadecimal, independent of the package's own parser.
Uint8List hexBytes(String hex) => Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);

String str(Map<String, Object?> c, String key) => c[key] as String;

void main() {
  test('metadata', () {
    expect(vectors['spec_version'], '1.0.0');
    expect(vectors['alphabet'], uuid58Alphabet);
  });

  group('roundtrip', () {
    for (final c in cases(['roundtrip'])) {
      test(str(c, 'description'), () {
        final uuid = str(c, 'uuid');
        final id = str(c, 'uuid58');
        final bytes = hexBytes(uuid.replaceAll('-', ''));

        expect(uuid58Encode(uuid), id);
        expect(uuid58Encode(uuid.replaceAll('-', '')), id);
        expect(uuid58EncodeBytes(bytes), id);
        expect(uuid58Decode(id), uuid);
        expect(uuid58DecodeBytes(id), bytes);
        expect(isUuid58(id), isTrue);
      });
    }
  });

  group('encode.valid', () {
    for (final c in cases(['encode', 'valid'])) {
      test(str(c, 'description'), () {
        expect(uuid58Encode(str(c, 'input')), str(c, 'output'));
      });
    }
  });

  group('encode.invalid', () {
    // Cases marked `lenient` are accepted by JavaScript 1.x only; this
    // implementation is strict and must reject them like any other.
    for (final c in cases(['encode', 'invalid'])) {
      test(str(c, 'description'), () {
        expect(
          () => uuid58Encode(str(c, 'input')),
          throwsKind(c['errors'] as List<Object?>),
        );
      });
    }
  });

  group('encode.invalid_bytes', () {
    for (final c in cases(['encode', 'invalid_bytes'])) {
      test(str(c, 'description'), () {
        expect(
          () => uuid58EncodeBytes(hexBytes(str(c, 'bytes'))),
          throwsKind(c['errors'] as List<Object?>),
        );
      });
    }
  });

  // encode.invalid_integers does not apply: there is no integer API.

  group('decode.invalid', () {
    for (final c in cases(['decode', 'invalid'])) {
      test(str(c, 'description'), () {
        final input = str(c, 'input');
        final kinds = throwsKind(c['errors'] as List<Object?>);
        expect(() => uuid58Decode(input), kinds);
        expect(() => uuid58DecodeBytes(input), kinds);
        expect(isUuid58(input), isFalse);
      });
    }
  });

  group('Section 4.1: ill-formed UTF-16', () {
    const anyKind = ['invalid_length', 'invalid_character'];

    test('lone surrogates are rejected by decoding', () {
      for (final s in [0xd800, 0xdbff, 0xdc00, 0xdfff]) {
        // 22 code units with a lone surrogate at the end and at the start.
        for (final input in [
          'XDY9dmBbcMBXqcRvYw8xJ${String.fromCharCode(s)}',
          '${String.fromCharCode(s)}DY9dmBbcMBXqcRvYw8xJ2',
        ]) {
          expect(() => uuid58Decode(input), throwsKind(anyKind));
          expect(() => uuid58DecodeBytes(input), throwsKind(anyKind));
          expect(isUuid58(input), isFalse);
        }
      }
    });

    test('lone surrogates are rejected by UUID parsing', () {
      for (final s in [0xd800, 0xdfff]) {
        final c = String.fromCharCode(s);
        for (final input in [
          'f4b247fd1f8745d4aa061c6fc0a8dfa$c',
          'f4b247fd-1f87-45d4-aa06-1c6fc0a8dfa$c',
          'f4b247fd${c}1f87-45d4-aa06-1c6fc0a8dfaf',
        ]) {
          expect(() => uuid58Encode(input), throwsKind(anyKind));
        }
      }
    });

    test('no non-ASCII code unit is mapped to an ASCII one', () {
      const valid = 'XDY9dmBbcMBXqcRvYw8xJ2';
      // Includes values whose low 7 or 8 bits are alphabet characters.
      for (final unit in [0x80, 0xc1, 0xff, 0x141, 0x171, 0xff21, 0xffff]) {
        for (var pos = 0; pos < valid.length; pos++) {
          final input = valid.replaceRange(
            pos,
            pos + 1,
            String.fromCharCode(unit),
          );
          expect(
            () => uuid58Decode(input),
            throwsKind(['invalid_character']),
          );
          expect(isUuid58(input), isFalse);
        }
      }
    });
  });
}

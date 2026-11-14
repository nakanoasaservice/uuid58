import { readFileSync } from "node:fs";

import { describe, expect, it } from "vite-plus/test";

import { UUID58_ALPHABET } from "./alphabet.ts";
import { isUuid58 } from "./check.ts";
import { Uuid58DecodeError, uuid58DecodeSafe } from "./decode.ts";
import { Uuid58EncodeError, uuid58EncodeSafe } from "./encode.ts";

// Conformance tests against the language-neutral test vectors in spec/.
// See spec/SPEC.md, Section 8.

interface Case {
  description: string;
}

interface Vectors {
  spec_version: string;
  alphabet: string;
  roundtrip: (Case & { uuid: string; uuid58: string })[];
  encode: {
    valid: (Case & { input: string; output: string })[];
    invalid: (Case & {
      input: string;
      errors: string[];
      lenient?: boolean;
      lenient_output?: string;
    })[];
    // Not tested: the JS API has no byte or integer input (SPEC.md 3.3).
    invalid_bytes: (Case & { bytes: string; errors: string[] })[];
    invalid_integers: (Case & { integer: string; errors: string[] })[];
  };
  decode: {
    invalid: (Case & { input: string; errors: string[] })[];
  };
}

const vectors = JSON.parse(
  readFileSync(new URL("../spec/vectors.json", import.meta.url), "utf8"),
) as Vectors;

describe(`spec vectors (spec ${vectors.spec_version})`, () => {
  it("uses the same alphabet", () => {
    expect(UUID58_ALPHABET).toBe(vectors.alphabet);
  });

  describe("roundtrip", () => {
    for (const c of vectors.roundtrip) {
      it(c.description, () => {
        expect(uuid58EncodeSafe(c.uuid)).toBe(c.uuid58);
        expect(uuid58DecodeSafe(c.uuid58)).toBe(c.uuid);
        expect(isUuid58(c.uuid58)).toBe(true);
      });
    }
  });

  describe("encode: valid", () => {
    for (const c of vectors.encode.valid) {
      it(c.description, () => {
        expect(uuid58EncodeSafe(c.input)).toBe(c.output);
      });
    }
  });

  describe("encode: invalid", () => {
    for (const c of vectors.encode.invalid) {
      // 1.x keeps accepting lenient inputs (SPEC.md, Section 9.1).
      // TODO(2.0): reject these like every other invalid input.
      if (c.lenient) {
        it(`${c.description} (lenient: accepted by 1.x)`, () => {
          expect(uuid58EncodeSafe(c.input)).toBe(c.lenient_output);
        });
        continue;
      }
      it(c.description, () => {
        expect(uuid58EncodeSafe(c.input)).toBeInstanceOf(Uuid58EncodeError);
      });
    }
  });

  describe("decode: invalid", () => {
    for (const c of vectors.decode.invalid) {
      it(c.description, () => {
        expect(uuid58DecodeSafe(c.input)).toBeInstanceOf(Uuid58DecodeError);
        expect(isUuid58(c.input)).toBe(false);
      });
    }
  });
});

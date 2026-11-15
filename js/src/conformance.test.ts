import { readFileSync } from "node:fs";

import { describe, expect, it } from "vite-plus/test";

import {
  isUuid58,
  UUID58_ALPHABET,
  Uuid58DecodeError,
  uuid58DecodeBytesSafe,
  uuid58DecodeSafe,
  Uuid58EncodeError,
  uuid58EncodeBytes,
  uuid58EncodeBytesSafe,
  uuid58EncodeSafe,
} from "./index.ts";

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
      // Only for 1.x (SPEC.md, Section 9.1).
      lenient?: boolean;
      lenient_output?: string;
    })[];
    invalid_bytes: (Case & { bytes: string; errors: string[] })[];
    // Not tested: the JS API has no integer input (SPEC.md 3.3).
    invalid_integers: (Case & { integer: string; errors: string[] })[];
  };
  decode: {
    invalid: (Case & { input: string; errors: string[] })[];
  };
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = Number.parseInt(hex.slice(2 * i, 2 * i + 2), 16);
  }
  return bytes;
}

const vectors = JSON.parse(
  readFileSync(new URL("../../spec/vectors.json", import.meta.url), "utf8"),
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

        const bytes = hexToBytes(c.uuid.replace(/-/g, ""));
        expect(uuid58EncodeBytes(bytes)).toBe(c.uuid58);
        expect(uuid58DecodeBytesSafe(c.uuid58)).toEqual(bytes);
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

  // Includes the vectors marked `lenient`: only 1.x accepted them
  // (SPEC.md, Section 9.1).
  describe("encode: invalid", () => {
    for (const c of vectors.encode.invalid) {
      it(c.description, () => {
        const result = uuid58EncodeSafe(c.input);
        expect(result).toBeInstanceOf(Uuid58EncodeError);
        expect(c.errors).toContain((result as Uuid58EncodeError).kind);
      });
    }
  });

  describe("encode: invalid bytes", () => {
    for (const c of vectors.encode.invalid_bytes) {
      it(c.description, () => {
        const result = uuid58EncodeBytesSafe(hexToBytes(c.bytes));
        expect(result).toBeInstanceOf(Uuid58EncodeError);
        expect(c.errors).toContain((result as Uuid58EncodeError).kind);
      });
    }
  });

  describe("decode: invalid", () => {
    for (const c of vectors.decode.invalid) {
      it(c.description, () => {
        const result = uuid58DecodeSafe(c.input);
        expect(result).toBeInstanceOf(Uuid58DecodeError);
        expect(c.errors).toContain((result as Uuid58DecodeError).kind);
        expect(uuid58DecodeBytesSafe(c.input)).toBeInstanceOf(
          Uuid58DecodeError,
        );
        expect(isUuid58(c.input)).toBe(false);
      });
    }
  });
});

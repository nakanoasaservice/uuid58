import { UUID58_ALPHABET, UUID58_LENGTH } from "./alphabet.ts";
import { isUuid58, UUID58_REGEX } from "./check.ts";
import { uuid58Decode } from "./decode.ts";
import { uuid58Encode } from "./encode.ts";
import { uuid58 } from "./generate.ts";

const TEST_UUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
const TEST_UUID58 = "XDY9dmBbcMBXqcRvYw8xJ2";

// ============================================================================
// Encode/Decode Functions
// ============================================================================

Deno.bench("uuid58Encode", () => {
  uuid58Encode(TEST_UUID);
});

Deno.bench("uuid58Decode", () => {
  uuid58Decode(TEST_UUID58);
});

// ============================================================================
// UUID58 Generation Functions
// ============================================================================

function uuid58RandomUUID(): string {
  let num = BigInt("0x" + crypto.randomUUID().replace(/-/g, ""));
  let encoded = "";

  do {
    encoded = UUID58_ALPHABET[Number(num % UUID58_LENGTH)] + encoded;
    num /= UUID58_LENGTH;
  } while (num > 0n);

  return encoded.padStart(22, UUID58_ALPHABET[0]);
}

Deno.bench("uuid58", () => {
  uuid58();
});

Deno.bench("uuid58RandomUUID", () => {
  uuid58RandomUUID();
});

// ============================================================================
// UUID58 Validation Functions
// ============================================================================

const MAX_UUID_VALUE = (1n << 128n) - 1n;
const MAX_UUID58 = "YcVfxkQb6JRzqk5kF2tNLv"; // cspell:disable-line
const MAX_UUID58_CODES = Array.from(MAX_UUID58, (char) => char.charCodeAt(0));

const BASE58_MAP: Record<string, bigint> = {};
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_MAP[UUID58_ALPHABET[i]!] = BigInt(i);
}

function isUuid58Regex(value: string): boolean {
  if (!UUID58_REGEX.test(value)) {
    return false;
  }

  let isBelowMax = false;
  for (let i = 0; i < value.length; i++) {
    const code = value.charCodeAt(i);

    if (!isBelowMax) {
      const maxCode = MAX_UUID58_CODES[i]!;
      if (code < maxCode) {
        isBelowMax = true;
      } else if (code > maxCode) {
        return false;
      }
    }
  }

  return true;
}

function isUuid58RangeList(value: string): boolean {
  if (value.length !== 22) {
    return false;
  }

  let isBelowMax = false;
  for (let i = 0; i < value.length; i++) {
    const code = value.charCodeAt(i);
    const isValid = (code >= 49 && code <= 57) || // '1'..'9'
      (code >= 65 && code <= 72) || // 'A'..'H'
      (code >= 74 && code <= 78) || // 'J'..'N'
      (code >= 80 && code <= 90) || // 'P'..'Z'
      (code >= 97 && code <= 107) || // 'a'..'k'
      (code >= 109 && code <= 122); // 'm'..'z'
    if (!isValid) {
      return false;
    }

    if (!isBelowMax) {
      const maxCode = MAX_UUID58_CODES[i]!;
      if (code < maxCode) {
        isBelowMax = true;
      } else if (code > maxCode) {
        return false;
      }
    }
  }

  return true;
}

function isUuid58Naive(value: string): boolean {
  if (value.length !== 22) {
    return false;
  }

  let num = 0n;
  for (const char of value) {
    const index = BASE58_MAP[char];
    if (index === undefined) {
      return false;
    }
    num = num * UUID58_LENGTH + index;
    if (num > MAX_UUID_VALUE) {
      return false;
    }
  }

  return num <= MAX_UUID_VALUE;
}

Deno.bench("isUuid58", () => {
  isUuid58(TEST_UUID58);
});

Deno.bench("isUuid58Regex", () => {
  isUuid58Regex(TEST_UUID58);
});

Deno.bench("isUuid58RangeList", () => {
  isUuid58RangeList(TEST_UUID58);
});

Deno.bench("isUuid58Naive", () => {
  isUuid58Naive(TEST_UUID58);
});

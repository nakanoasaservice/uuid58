import { UUID58_ALPHABET, UUID58_LENGTH } from "./alphabet.ts";
import { isUuid58, UUID58_REGEX } from "./check.ts";
import { uuid58Decode } from "./decode.ts";
import { uuid58Encode } from "./encode.ts";
import { uuid58 } from "./generate.ts";

Deno.bench("uuid58Encode", () => {
  uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
});

Deno.bench("uuid58Decode", () => {
  uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2");
});

Deno.bench("uuid58 (using crypto.getRandomValues)", () => {
  uuid58();
});

Deno.bench("uuid58 (using crypto.randomUUID)", () => {
  uuid58RandomUUID();
});

function uuid58RandomUUID(): string {
  let num = BigInt("0x" + crypto.randomUUID().replace(/-/g, ""));
  let encoded = "";

  do {
    encoded = UUID58_ALPHABET[Number(num % UUID58_LENGTH)] + encoded;
    num /= UUID58_LENGTH;
  } while (num > 0n);

  return encoded.padStart(22, UUID58_ALPHABET[0]);
}

Deno.bench("isUuid58", () => {
  isUuid58("XDY9dmBbcMBXqcRvYw8xJ2");
});

// UUID max value encoded in Base58 (length 22)
const MAX_UUID58 = "YcVfxkQb6JRzqk5kF2tNLv"; // cspell:disable-line
const MAX_UUID58_CODES = Array.from(MAX_UUID58, (char) => char.charCodeAt(0));

function isUuid58Regex(value: string): boolean {
  if (!UUID58_REGEX.test(value)) {
    return false;
  }

  // Compare chars against the max-UUID Base58 string using ASCII order
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

Deno.bench("isUuid58Regex", () => {
  isUuid58Regex("XDY9dmBbcMBXqcRvYw8xJ2");
});

const MAX_UUID_VALUE = (1n << 128n) - 1n;
const BASE58_MAP: Record<string, bigint> = {};
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_MAP[UUID58_ALPHABET[i]!] = BigInt(i);
}

export function isUuid58Naive(value: string): boolean {
  // Check length: UUID58 strings must be exactly 22 characters
  if (value.length !== 22) {
    return false;
  }

  // Convert Base58 string to BigInt and check if it's within UUID range
  let num = 0n;
  for (const char of value) {
    const index = BASE58_MAP[char];
    // Check if character is in the Base58 alphabet
    if (index === undefined) {
      return false;
    }
    num = num * UUID58_LENGTH + index;
    // Early exit: if we exceed the maximum UUID value, it's invalid
    if (num > MAX_UUID_VALUE) {
      return false;
    }
  }

  // Verify the decoded value fits within 128 bits
  return num <= MAX_UUID_VALUE;
}

Deno.bench("isUuid58Naive", () => {
  isUuid58Naive("XDY9dmBbcMBXqcRvYw8xJ2");
});

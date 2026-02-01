import { UUID58_ALPHABET, UUID58_LENGTH } from "../alphabet.ts";
import { isUuid58, UUID58_REGEX } from "../check.ts";

const MAX_UUID_VALUE = (1n << 128n) - 1n;
const MAX_UUID58 = "YcVfxkQb6JRzqk5kF2tNLv"; // cspell:disable-line
const MAX_UUID58_CODES = Array.from(MAX_UUID58, (char) => char.charCodeAt(0));

const BASE58_MAP: Record<string, bigint> = {};
for (let i = 0; i < UUID58_ALPHABET.length; i++) {
  BASE58_MAP[UUID58_ALPHABET[i]!] = BigInt(i);
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

Deno.bench("isUuid58Naive", () => {
  isUuid58Naive(MAX_UUID58);
});

Deno.bench("isUuid58 (current)", () => {
  isUuid58(MAX_UUID58);
});

function isUuid58CharCodeRangeCheck(value: string): boolean {
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

Deno.bench("isUuid58CharCodeRangeCheck", () => {
  isUuid58CharCodeRangeCheck(MAX_UUID58);
});

function isUuid58CharCodeExcludeCheck(uuid58: string): boolean {
  if (uuid58.length !== 22) {
    return false;
  }

  let isBelowMax = false;
  for (let i = 0; i < 22; i++) {
    const code = uuid58.charCodeAt(i);

    if (
      code < 49 ||
      (code >= 58 && code <= 64) || // ':'..'@'
      code === 73 || // 'I'
      code === 79 || // 'O'
      (code >= 91 && code <= 96) || // '['..'`'
      code === 108 || // 'l'
      code > 122
    ) {
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

Deno.bench("isUuid58CharCodeExcludeCheck", () => {
  isUuid58CharCodeExcludeCheck(MAX_UUID58);
});

function isUuid58RegexCharCode(uuid58: string): boolean {
  if (
    !UUID58_REGEX.test(uuid58)
  ) {
    return false;
  }

  for (let i = 0; i < 22; i++) {
    const char = uuid58.charCodeAt(i);
    const maxChar = MAX_UUID58_CODES[i]!;

    if (char < maxChar) {
      return true;
    } else if (char > maxChar) {
      return false;
    }
  }

  return true;
}

Deno.bench("isUuid58RegexCharCode", () => {
  isUuid58RegexCharCode(MAX_UUID58);
});

function isUuid58RegexCharCodeDirect(uuid58: string): boolean {
  if (
    !UUID58_REGEX.test(uuid58)
  ) {
    return false;
  }

  for (let i = 0; i < 22; i++) {
    const char = uuid58[i]!;
    const maxChar = MAX_UUID58[i]!;

    if (char < maxChar) {
      return true;
    } else if (char > maxChar) {
      return false;
    }
  }

  return true;
}

Deno.bench("isUuid58RegexCharCodeDirect", () => {
  isUuid58RegexCharCodeDirect(MAX_UUID58);
});

export function isUuid58StringComparison(uuid58: string): boolean {
  return UUID58_REGEX.test(uuid58) && uuid58 <= MAX_UUID58;
}

Deno.bench("isUuid58DirectComparison", () => {
  isUuid58StringComparison(MAX_UUID58);
});

import { UUID58_ALPHABET, UUID58_LENGTH } from "../alphabet.ts";
import { Uuid58EncodeError, uuid58EncodeSafe } from "../encode.ts";

const TEST_UUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";

Deno.bench("uuid58Encode (current)", () => {
  uuid58EncodeSafe(TEST_UUID);
});

function uuid58EncodeArrayBased(uuid: string) {
  const hex = uuid.replace(/-/g, "");
  if (hex.length !== 32) {
    return new Uuid58EncodeError(
      `Invalid UUID length: expected 32 characters (excluding hyphens), got ${hex.length} characters in "${uuid}"`,
    );
  }

  let num;
  try {
    num = BigInt("0x" + hex);
  } catch {
    return new Uuid58EncodeError(
      `Invalid UUID format: "${uuid}" contains non-hexadecimal characters`,
    );
  }

  const out = new Array<string>(22).fill(UUID58_ALPHABET[0]!);
  let i = 21;
  while (num > 0n) {
    const rem = Number(num % UUID58_LENGTH);
    out[i--] = UUID58_ALPHABET[rem]!;
    num /= UUID58_LENGTH;
  }

  return out.join("");
}

Deno.bench("uuid58EncodeArrayBased", () => {
  uuid58EncodeArrayBased(TEST_UUID);
});

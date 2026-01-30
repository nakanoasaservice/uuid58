import { UUID58_ALPHABET, UUID58_LENGTH } from "./alphabet.ts";
import { uuid58Decode } from "./decode.ts";
import { uuid58Encode } from "./encode.ts";
import { uuid58 } from "./uuid58.ts";

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

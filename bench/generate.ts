import { UUID58_ALPHABET, UUID58_LENGTH } from "../alphabet.ts";
import { uuid58 } from "../generate.ts";

Deno.bench("uuid58 (current)", () => {
  uuid58();
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

Deno.bench("uuid58RandomUUID", () => {
  uuid58RandomUUID();
});

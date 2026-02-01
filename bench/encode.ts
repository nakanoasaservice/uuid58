import { uuid58Encode } from "../encode.ts";

const TEST_UUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";

Deno.bench("uuid58Encode (current)", () => {
  uuid58Encode(TEST_UUID);
});

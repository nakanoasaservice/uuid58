import { uuid58Decode } from "./decode.ts";
import { uuid58Encode } from "./encode.ts";
import { uuid58 } from "./uuid58.ts";

Deno.bench("uuid58Encode", () => {
  uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
});

Deno.bench("uuid58Decode", () => {
  uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2");
});

Deno.bench("uuid58", () => {
  uuid58();
});

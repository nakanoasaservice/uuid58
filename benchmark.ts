import { uuid58Decode } from "./decode.ts";
import { uuid58Encode } from "./encode.ts";

Deno.bench("uuid58Encode", () => {
  for (let i = 0; i < 10000; i++) {
    uuid58Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
  }
});

Deno.bench("uuid58Decode", () => {
  for (let i = 0; i < 10000; i++) {
    uuid58Decode("XDY9dmBbcMBXqcRvYw8xJ2");
  }
});

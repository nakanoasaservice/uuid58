import { encodeUuid58 } from "./encode.ts";
import { decodeUuid58 } from "./decode.ts";

Deno.bench("encodeUuid58", () => {
  for (let i = 0; i < 10000; i++) {
    encodeUuid58("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf");
  }
});

Deno.bench("decodeUuid58", () => {
  for (let i = 0; i < 10000; i++) {
    decodeUuid58("XDY9dmBbcMBXqcRvYw8xJ2");
  }
});

import { uuid58Decode } from "../decode.ts";

const MAX_UUID58 = "YcVfxkQb6JRzqk5kF2tNLv";

Deno.bench("uuid58Decode (current)", () => {
  uuid58Decode(MAX_UUID58);
});

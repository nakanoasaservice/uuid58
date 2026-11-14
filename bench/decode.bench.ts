import { test } from "vite-plus/test";

import { uuid58Decode } from "../decode.ts";

const MAX_UUID58 = "YcVfxkQb6JRzqk5kF2tNLv";

test("uuid58Decode (current)", async ({ bench }) => {
  await bench("uuid58Decode (current)", () => {
    uuid58Decode(MAX_UUID58);
  }).run();
});

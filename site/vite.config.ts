import { fileURLToPath } from "node:url";
import { defineConfig } from "vite-plus";
import solid from "vite-plugin-solid";

export default defineConfig({
  plugins: [solid()],
  base: "/uuid58/",
  resolve: {
    // Use the library source in this repository, so the site always matches main.
    alias: {
      "@nakanoaas/uuid58": fileURLToPath(
        new URL("../js/index.ts", import.meta.url),
      ),
    },
  },
  lint: {
    ignorePatterns: ["dist/**"],
    options: { typeAware: true, typeCheck: true },
  },
  fmt: {
    printWidth: 80,
    ignorePatterns: ["dist/**", "pnpm-lock.yaml"],
  },
});

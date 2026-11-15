import { fileURLToPath } from "node:url";
import { defineConfig, runnerImport, type Plugin } from "vite-plus";
import solid from "vite-plugin-solid";
import { highlight } from "./highlight";

// Use the library source in this repository, so the site always matches main.
const alias = {
  "@nakanoaas/uuid58": fileURLToPath(
    new URL("../js/src/index.ts", import.meta.url),
  ),
};

/**
 * Prerenders the app into index.html at build time, so the static content
 * shows without JavaScript. The client entry then hydrates it.
 */
function prerender(): Plugin {
  return {
    name: "uuid58:prerender",
    apply: "build",
    async transformIndexHtml(html) {
      const { module } = await runnerImport<typeof import("./prerender.tsx")>(
        fileURLToPath(new URL("./prerender.tsx", import.meta.url)),
        {
          configFile: false,
          logLevel: "warn",
          plugins: [solid({ ssr: true }), highlight()],
          resolve: { alias },
        },
      );
      const { html: app, head } = module.prerender();
      const marker = '<div id="app"></div>';
      if (!html.includes(marker)) throw new Error(`Missing ${marker}`);
      return html
        .replace(marker, () => `<div id="app">${app}</div>`)
        .replace("</head>", () => `${head}</head>`);
    },
  };
}

export default defineConfig({
  plugins: [solid({ ssr: true }), highlight(), prerender()],
  base: "/uuid58/",
  resolve: { alias },
  lint: {
    ignorePatterns: ["dist/**"],
    options: { typeAware: true, typeCheck: true },
  },
  fmt: {
    printWidth: 80,
    ignorePatterns: ["dist/**", "pnpm-lock.yaml"],
  },
});

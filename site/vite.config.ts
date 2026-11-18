import { fileURLToPath } from "node:url";
import { defineConfig, runnerImport, type Plugin } from "vite-plus";
import solid from "@solidjs/vite-plugin";
import { highlight } from "./highlight";
import { specPage, specVersion } from "./spec-page";

// Use the library source in this repository, so the site always matches main.
const alias = {
  "@nakanoaas/uuid58": fileURLToPath(
    new URL("../js/src/index.ts", import.meta.url),
  ),
};

const define = { __SPEC_VERSION__: JSON.stringify(specVersion()) };

/**
 * Prerenders the app into index.html at build time, so the static content
 * shows without JavaScript. The client entry then hydrates it.
 */
function prerender(): Plugin {
  return {
    name: "uuid58:prerender",
    apply: "build",
    async transformIndexHtml(html, ctx) {
      // Only the home page is a Solid app; spec/index.html is static.
      if (ctx.path !== "/index.html") return;
      const { module } = await runnerImport<typeof import("./prerender.tsx")>(
        fileURLToPath(new URL("./prerender.tsx", import.meta.url)),
        {
          configFile: false,
          logLevel: "warn",
          define,
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
  plugins: [solid({ ssr: true }), highlight(), prerender(), specPage()],
  base: "/uuid58/",
  // Only the version string reaches the client, not the whole spec.
  define,
  build: {
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL("./index.html", import.meta.url)),
        spec: fileURLToPath(new URL("./spec/index.html", import.meta.url)),
      },
    },
  },
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

// Syntax highlighting at build time. This Vite plugin serves the virtual module
// `virtual:highlighted`: every code block on the page as highlighted HTML, so
// Shiki never ships to the browser.
import { createHighlighter } from "shiki";
import type { Plugin } from "vite-plus";
import { installMethods, tryCommand, usageExample } from "./cli";
import { libraries } from "./libraries";

const id = "virtual:highlighted";
const resolvedId = `\0${id}`;

export function highlight(): Plugin {
  return {
    name: "uuid58:highlight",
    resolveId(source) {
      return source === id ? resolvedId : undefined;
    },
    async load(moduleId) {
      if (moduleId !== resolvedId) return;

      const highlighter = await createHighlighter({
        themes: ["github-light", "github-dark"],
        langs: [
          ...new Set(libraries.map((s) => s.language)),
          "shellscript",
          "shellsession",
        ],
      });

      // Only the token spans: the page supplies its own <pre><code>.
      const toHtml = (code: string, lang: string) => {
        const html = highlighter.codeToHtml(code, {
          lang,
          themes: { light: "github-light", dark: "github-dark" },
          defaultColor: false,
        });
        const inner = /<code>([\s\S]*)<\/code>/.exec(html)?.[1];
        if (inner === undefined) throw new Error(`Unexpected Shiki output`);
        return inner;
      };

      const highlighted = {
        libraries: Object.fromEntries(
          libraries.map((s) => [
            s.id,
            {
              install: toHtml(s.install, "shellscript"),
              code: toHtml(s.code, s.language),
            },
          ]),
        ),
        install: Object.fromEntries(
          installMethods.map((m) => [m.id, toHtml(m.command, "shellscript")]),
        ),
        try: toHtml(tryCommand, "shellscript"),
        usage: toHtml(usageExample, "shellsession"),
      };
      highlighter.dispose();
      return `export default ${JSON.stringify(highlighted)};`;
    },
  };
}

// Syntax highlighting at build time. This Vite plugin serves the virtual module
// `virtual:highlighted`: every code block on the page as highlighted HTML, so
// Shiki never ships to the browser. The code samples are highlighted with the
// sample pair filled in; app.tsx swaps in the playground values with fill().
import { createHighlighter } from "shiki";
import type { Plugin } from "vite-plus";
import { installMethods, usageExample } from "./cli";
import { sample, samples } from "./samples";

const id = "virtual:highlighted";
const resolvedId = `\0${id}`;

function count(text: string, part: string): number {
  return text.split(part).length - 1;
}

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
          ...new Set(samples.map((s) => s.language)),
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

      // fill() finds the sample values by exact text, so each must survive
      // highlighting as one unbroken run.
      const withValues = (code: string, lang: string) => {
        const html = toHtml(code, lang);
        for (const value of [sample.encoded, sample.decoded]) {
          if (count(html, value) !== count(code, value)) {
            throw new Error(`Highlighting split ${value} in:\n${code}`);
          }
        }
        return html;
      };

      const highlighted = {
        samples: Object.fromEntries(
          samples.map((s) => [
            s.id,
            {
              install: toHtml(s.install, "shellscript"),
              code: withValues(s.code(sample), s.language),
            },
          ]),
        ),
        install: Object.fromEntries(
          installMethods.map((m) => [m.id, toHtml(m.command, "shellscript")]),
        ),
        usage: withValues(usageExample(sample), "shellsession"),
      };
      highlighter.dispose();
      return `export default ${JSON.stringify(highlighted)};`;
    },
  };
}

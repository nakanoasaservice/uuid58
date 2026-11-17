// Renders spec/SPEC.md into spec/index.html at build time (and in the dev
// server), so the specification is a static page on the site with no
// JavaScript. Headings get GitHub-style ids, so links such as
// SPEC.md#51-accepted-forms work on both GitHub and the site.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { Marked } from "marked";
import { createHighlighter } from "shiki";
import type { Plugin } from "vite-plus";

const SPEC_PATH = fileURLToPath(new URL("../spec/SPEC.md", import.meta.url));
const BLOB = "https://github.com/nakanoasaservice/uuid58/blob/main/spec/";
const MARKER = "<!--spec-->";

/** The spec's version, from its "**Version:** x.y.z" line. */
export function specVersion(): string {
  const version = /\*\*Version:\*\*\s*(\S+)/.exec(
    readFileSync(SPEC_PATH, "utf8"),
  )?.[1];
  if (!version) throw new Error("No version in spec/SPEC.md");
  return version;
}

/** GitHub's heading anchor: lowercase, punctuation dropped, spaces to -. */
function slug(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s_-]/gu, "")
    .trim()
    .replace(/\s/g, "-");
}

function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function render(): Promise<string> {
  const markdown = readFileSync(SPEC_PATH, "utf8");
  const highlighter = await createHighlighter({
    themes: ["github-light", "github-dark"],
    langs: ["jsonc", "bash", "python"],
  });
  const loaded = new Set(highlighter.getLoadedLanguages());

  const marked = new Marked({
    gfm: true,
    renderer: {
      heading({ tokens, depth, text }) {
        const id = slug(text);
        return `<h${depth} id="${id}">${this.parser.parseInline(tokens)}</h${depth}>\n`;
      },
      link({ href, title, tokens }) {
        // Relative links point at files next to SPEC.md in the repository.
        const url = /^(https?:|mailto:|#)/.test(href) ? href : BLOB + href;
        const titleAttr = title ? ` title="${escapeHtml(title)}"` : "";
        return `<a href="${escapeHtml(url)}"${titleAttr}>${this.parser.parseInline(tokens)}</a>`;
      },
      code({ text, lang }) {
        const language = lang && loaded.has(lang) ? lang : "text";
        const html = highlighter.codeToHtml(text, {
          lang: language,
          themes: { light: "github-light", dark: "github-dark" },
          defaultColor: false,
        });
        const inner = /<code>([\s\S]*)<\/code>/.exec(html)?.[1];
        if (inner === undefined) throw new Error("Unexpected Shiki output");
        return `<div class="code-block"><pre><code>${inner}</code></pre></div>\n`;
      },
      table(token) {
        // Wide tables scroll inside their box on phones.
        const header = token.header
          .map((cell) => `<th>${this.parser.parseInline(cell.tokens)}</th>`)
          .join("");
        const rows = token.rows
          .map(
            (row) =>
              `<tr>${row.map((cell) => `<td>${this.parser.parseInline(cell.tokens)}</td>`).join("")}</tr>`,
          )
          .join("\n");
        return `<div class="table-scroll"><table><thead><tr>${header}</tr></thead><tbody>${rows}</tbody></table></div>\n`;
      },
    },
  });

  const html = await marked.parse(markdown);
  highlighter.dispose();
  return html;
}

export function specPage(): Plugin {
  return {
    name: "uuid58:spec-page",
    async transformIndexHtml(html, ctx) {
      if (!ctx.path.endsWith("/spec/index.html")) return;
      if (!html.includes(MARKER)) throw new Error(`Missing ${MARKER}`);
      const body = await render();
      return html.replace(MARKER, () => body);
    },
  };
}

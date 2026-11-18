// Renders the page to HTML at build time. vite.config.ts loads this through a
// server-side Vite module runner and writes the result into index.html, so the
// page reads without JavaScript and main.tsx hydrates it in place.
import { generateHydrationScript, renderToString } from "@solidjs/web";
import { App } from "./app";

export function prerender(): { html: string; head: string } {
  return {
    html: renderToString(() => <App />),
    head: generateHydrationScript(),
  };
}

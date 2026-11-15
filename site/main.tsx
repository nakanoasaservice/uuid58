import { hydrate, render } from "solid-js/web";
import { App } from "./app";
import "./global.css";

const root = document.getElementById("app");
if (!root) throw new Error("Missing app root");

// The build prerenders the page into #app (see prerender.tsx); the dev server
// serves it empty, so render from scratch there.
if (import.meta.env.DEV) {
  render(() => <App />, root);
} else {
  hydrate(() => <App />, root);
}

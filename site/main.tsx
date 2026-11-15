import { createSignal, For, onCleanup, Show } from "solid-js";
import { render } from "solid-js/web";
import {
  uuid58,
  uuid58Decode,
  uuid58DecodeSafe,
  uuid58EncodeSafe,
} from "@nakanoaas/uuid58";
import spec from "../spec/SPEC.md?raw";
import "./global.css";
import {
  cliDocs,
  cliReleases,
  commands,
  installMethods,
  usageExample,
} from "./cli";
import { samples } from "./samples";

const REPO = "https://github.com/nakanoasaservice/uuid58";
const SPEC_VERSION = /\*\*Version:\*\*\s*(\S+)/.exec(spec)?.[1] ?? "";
const SAMPLE_UUID = "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf";
const SAMPLE_UUID58 = "XDY9dmBbcMBXqcRvYw8xJ2";

type Field = "encoded" | "decoded";
type Pair = { encoded: string; decoded: string };
type ConversionState = Pair & {
  error: { field: Field; name: string; message: string } | undefined;
  /** The last pair that converted successfully, for the code samples. */
  valid: Pair;
};

function newPair(): Pair {
  const encoded = uuid58();
  return { encoded, decoded: uuid58Decode(encoded) };
}

const fields: { key: Field; label: string; hint: string }[] = [
  { key: "encoded", label: "uuid58", hint: "22 characters" },
  { key: "decoded", label: "UUID", hint: "36 or 32 characters" },
];

const features = [
  {
    title: "Fixed 22 characters",
    body: "Always exactly 22 characters, padded with leading 1s. Easy to validate, store in a fixed-width column, and spot in logs.",
  },
  {
    title: "URL-safe and unambiguous",
    body: "Uses the Bitcoin Base58 alphabet: no symbols to escape, and no 0, O, I, or l to confuse when reading aloud or typing.",
  },
  {
    title: "Keeps sort order",
    body: "Encoded strings sort in the same order as the UUIDs they encode, so time-ordered UUIDs such as v7 stay time-ordered.",
  },
  {
    title: "One spec, many languages",
    body: "A written specification and shared test vectors make every implementation produce the same output for the same UUID.",
  },
];

/** A button that copies `text` and briefly shows the result. */
function CopyButton(props: { text: () => string; label?: string }) {
  const [status, setStatus] = createSignal<string>();
  let timer: ReturnType<typeof setTimeout> | undefined;
  onCleanup(() => clearTimeout(timer));

  async function copy() {
    clearTimeout(timer);
    try {
      await navigator.clipboard.writeText(props.text());
      setStatus("Copied");
    } catch {
      setStatus("Failed");
    }
    timer = setTimeout(() => setStatus(undefined), 1500);
  }

  return (
    <button
      type="button"
      class="copy"
      onClick={copy}
      aria-label={props.label ?? "Copy to clipboard"}
    >
      {status() ?? "Copy"}
    </button>
  );
}

function Playground(props: {
  conversion: () => ConversionState;
  setConversion: (
    update: (previous: ConversionState) => ConversionState,
  ) => void;
}) {
  const conversion = () => props.conversion();

  function generate() {
    const pair = newPair();
    props.setConversion(() => ({ ...pair, error: undefined, valid: pair }));
  }

  function convert(field: Field, value: string) {
    const decoding = field === "encoded";
    const result = decoding ? uuid58DecodeSafe(value) : uuid58EncodeSafe(value);
    props.setConversion((previous) => {
      if (typeof result !== "string") {
        return {
          ...previous,
          [field]: value,
          error: { field, name: result.name, message: result.message },
        };
      }
      const pair = decoding
        ? { encoded: value, decoded: result }
        : { encoded: result, decoded: value };
      return { ...pair, error: undefined, valid: pair };
    });
  }

  return (
    <div class="playground">
      <For each={fields}>
        {(field) => (
          <div class="field">
            <label for={`${field.key}-input`}>
              {field.label}
              <span>{field.hint}</span>
            </label>
            <div class="input-row">
              <input
                type="text"
                id={`${field.key}-input`}
                value={conversion()[field.key]}
                onInput={(event) =>
                  convert(field.key, event.currentTarget.value)
                }
                spellcheck={false}
                autocomplete="off"
                autocapitalize="off"
                aria-invalid={conversion().error?.field === field.key}
                aria-describedby={
                  conversion().error?.field === field.key
                    ? `${field.key}-error`
                    : undefined
                }
              />
              <CopyButton
                text={() => conversion()[field.key]}
                label={`Copy ${field.label}`}
              />
            </div>
            <Show
              when={
                conversion().error?.field === field.key && conversion().error
              }
            >
              {(issue) => (
                <div class="error" id={`${field.key}-error`} role="alert">
                  <strong>{issue().name}</strong> {issue().message}
                </div>
              )}
            </Show>
          </div>
        )}
      </For>
      <div class="playground-footer">
        <button type="button" class="primary" onClick={generate}>
          Generate new
        </button>
        <p>
          Random v4 UUIDs from <code>crypto.getRandomValues()</code>. Edit
          either field to convert it.
        </p>
      </div>
    </div>
  );
}

function Samples(props: { values: () => Pair }) {
  const [selected, setSelected] = createSignal(samples[0]!.id);
  const sample = () => samples.find((s) => s.id === selected()) ?? samples[0]!;
  const code = () => sample().code(props.values());

  return (
    <div class="samples">
      <div class="tabs" role="tablist" aria-label="Language">
        <For each={samples}>
          {(s) => (
            <button
              type="button"
              role="tab"
              id={`tab-${s.id}`}
              aria-selected={selected() === s.id}
              aria-controls="sample-panel"
              tabIndex={selected() === s.id ? 0 : -1}
              onClick={() => setSelected(s.id)}
              onKeyDown={(event) => {
                const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
                if (!step) return;
                const index = samples.findIndex((x) => x.id === selected());
                const next =
                  samples[(index + step + samples.length) % samples.length]!;
                setSelected(next.id);
                document.getElementById(`tab-${next.id}`)?.focus();
              }}
            >
              {s.label}
            </button>
          )}
        </For>
      </div>
      <div
        id="sample-panel"
        class="sample-panel"
        role="tabpanel"
        aria-labelledby={`tab-${sample().id}`}
      >
        <Show when={sample().note}>
          {(note) => <p class="sample-note">{note()}</p>}
        </Show>
        <div class="code-block">
          <pre>
            <code class={`language-${sample().language}`}>
              {sample().install}
            </code>
          </pre>
          <CopyButton
            text={() => sample().install}
            label="Copy install command"
          />
        </div>
        <div class="code-block">
          <pre>
            <code class={`language-${sample().language}`}>{code()}</code>
          </pre>
          <CopyButton text={code} label="Copy code sample" />
        </div>
        <p class="links">
          <a href={sample().docs}>{sample().label} documentation</a>
          <For each={sample().registries}>
            {(registry) => <a href={registry.href}>{registry.label}</a>}
          </For>
        </p>
      </div>
    </div>
  );
}

function CommandLine(props: { values: () => Pair }) {
  const [selected, setSelected] = createSignal(installMethods[0]!.id);
  const method = () =>
    installMethods.find((m) => m.id === selected()) ?? installMethods[0]!;
  const usage = () => usageExample(props.values());

  return (
    <div class="cli">
      <h3>Install</h3>
      <div class="tabs" role="tablist" aria-label="Install method">
        <For each={installMethods}>
          {(m) => (
            <button
              type="button"
              role="tab"
              id={`install-tab-${m.id}`}
              aria-selected={selected() === m.id}
              aria-controls="install-panel"
              tabIndex={selected() === m.id ? 0 : -1}
              onClick={() => setSelected(m.id)}
              onKeyDown={(event) => {
                const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
                if (!step) return;
                const index = installMethods.findIndex(
                  (x) => x.id === selected(),
                );
                const next =
                  installMethods[
                    (index + step + installMethods.length) %
                      installMethods.length
                  ]!;
                setSelected(next.id);
                document.getElementById(`install-tab-${next.id}`)?.focus();
              }}
            >
              {m.label}
            </button>
          )}
        </For>
      </div>
      <div
        id="install-panel"
        class="sample-panel"
        role="tabpanel"
        aria-labelledby={`install-tab-${method().id}`}
      >
        <div class="code-block">
          <pre>
            <code class="language-shell">{method().command}</code>
          </pre>
          <CopyButton
            text={() => method().command}
            label="Copy install command"
          />
        </div>
        <p class="sample-note">{method().note}</p>
      </div>
      <p class="sample-note">
        Prebuilt binaries for macOS, Linux, and Windows are on{" "}
        <a href={cliReleases}>GitHub Releases</a>. The CLI ships with the next
        Go release; until then, only the Nix flake installs it.
      </p>

      <h3>Usage</h3>
      <p>
        Each command takes values as arguments, or reads one per line from
        standard input when there are none, so it fits in a pipeline. Every
        input is processed, and each invalid one is reported on standard error
        with its error kind.
      </p>
      <div class="code-block">
        <pre>
          <code class="language-shell">{usage()}</code>
        </pre>
        <CopyButton text={usage} label="Copy usage example" />
      </div>

      <table class="commands">
        <thead>
          <tr>
            <th scope="col">Command</th>
            <th scope="col">What it does</th>
          </tr>
        </thead>
        <tbody>
          <For each={commands}>
            {(command) => (
              <tr>
                <td>
                  <code>uuid58 {command.usage}</code>
                </td>
                <td>{command.description}</td>
              </tr>
            )}
          </For>
        </tbody>
      </table>
      <p class="sample-note">
        Exit status: 0 on success, 1 if any input was invalid, 2 on a usage
        error.
      </p>
      <p class="links">
        <a href={cliDocs}>CLI documentation</a>
        <a href={cliReleases}>GitHub Releases</a>
      </p>
    </div>
  );
}

function App() {
  const initial = newPair();
  const [conversion, setConversion] = createSignal<ConversionState>({
    ...initial,
    error: undefined,
    valid: initial,
  });

  return (
    <>
      <header class="topbar">
        <div class="container topbar-inner">
          <a class="brand" href="./">
            uuid58
          </a>
          <nav aria-label="Main">
            <a href="#playground">Playground</a>
            <a href="#install">Install</a>
            <a href="#cli">CLI</a>
            <a href={`${REPO}/blob/main/spec/SPEC.md`}>Spec</a>
            <a href={REPO}>GitHub</a>
          </nav>
        </div>
      </header>

      <main>
        <section class="hero container">
          <h1>UUIDs in 22 characters.</h1>
          <p class="lead">
            uuid58 encodes a UUID as a fixed-length Base58 string. Shorter than
            the usual 36-character form, safe in URLs, and free of look-alike
            characters.
          </p>
          <div class="compare" aria-label="Example">
            <div>
              <span class="tag">UUID · 36</span>
              <code>{SAMPLE_UUID}</code>
            </div>
            <div>
              <span class="tag accent">uuid58 · 22</span>
              <code>{SAMPLE_UUID58}</code>
            </div>
          </div>
          <div class="cta">
            <a class="button primary" href="#playground">
              Try it
            </a>
            <a class="button" href={`${REPO}/blob/main/spec/SPEC.md`}>
              Read the spec
            </a>
          </div>
        </section>

        <section id="playground" class="container">
          <h2>Playground</h2>
          <Playground conversion={conversion} setConversion={setConversion} />
        </section>

        <section class="container">
          <h2>Why uuid58</h2>
          <ul class="features">
            <For each={features}>
              {(feature) => (
                <li>
                  <h3>{feature.title}</h3>
                  <p>{feature.body}</p>
                </li>
              )}
            </For>
          </ul>
        </section>

        <section id="install" class="container">
          <h2>Use it in your language</h2>
          <p>
            The samples below use the values from the playground. Every
            implementation follows{" "}
            <a href={`${REPO}/blob/main/spec/SPEC.md`}>
              the uuid58 specification
            </a>{" "}
            {SPEC_VERSION} and passes{" "}
            <a href={`${REPO}/blob/main/spec/vectors.json`}>its test vectors</a>
            .
          </p>
          <Samples values={() => conversion().valid} />
        </section>

        <section id="cli" class="container">
          <h2>Command line</h2>
          <p>
            <code>uuid58</code> is a small command-line tool built on the Go
            implementation: a single static binary with no dependencies. The
            example uses the values from the playground.
          </p>
          <CommandLine values={() => conversion().valid} />
        </section>
      </main>

      <footer class="container">
        <p>
          MIT License · <a href={REPO}>nakanoasaservice/uuid58</a>
        </p>
      </footer>
    </>
  );
}

const root = document.getElementById("app");
if (!root) throw new Error("Missing app root");
render(() => <App />, root);

import { createSignal, For, onCleanup, onMount, Show } from "solid-js";
import {
  uuid58,
  uuid58Decode,
  uuid58DecodeSafe,
  uuid58EncodeSafe,
} from "@nakanoaas/uuid58";
import {
  cliDocs,
  cliReleases,
  commands,
  installMethods,
  tryCommand,
  usageExample,
} from "./cli";
import highlighted from "virtual:highlighted";
import { sample as samplePair, samples } from "./samples";

const REPO = "https://github.com/nakanoasaservice/uuid58";
const SPEC_VERSION = __SPEC_VERSION__;
/** The spec page, rendered from spec/SPEC.md at build time. */
const SPEC = "./spec/";
const SAMPLE_UUID = samplePair.decoded;
const SAMPLE_UUID58 = samplePair.encoded;

type Field = "encoded" | "decoded";
type Pair = { encoded: string; decoded: string };
type ConversionState = Pair & {
  error: { field: Field; name: string; message: string } | undefined;
  /** The last pair that converted successfully, for the code samples. */
  valid: Pair;
};

function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

/** Puts `values` into code highlighted with the sample pair. */
function fill(html: string, values: Pair): string {
  return html
    .replaceAll(SAMPLE_UUID58, escapeHtml(values.encoded))
    .replaceAll(SAMPLE_UUID, escapeHtml(values.decoded));
}

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
    body: "Always exactly 22 characters, padded with leading 1s. Validate with one length check and store in a fixed-width column such as CHAR(22).",
  },
  {
    title: "URL-safe, no look-alikes",
    body: "Uses the Bitcoin Base58 alphabet: nothing to escape in URLs, and no 0, O, I, or l to confuse when reading or typing.",
  },
  {
    title: "Sortable",
    body: "Encoded strings sort in the same order as the UUIDs they encode, so UUIDv7 IDs stay time-ordered as strings.",
  },
  {
    title: "Same output in every language",
    body: "A string made in Go decodes to the same UUID in Python, Rust, or PostgreSQL.",
  },
  {
    title: "Stable, strict, well tested",
    body: "Spec 1.1.0 defines every accepted input and every error, and the format will not change within 1.x. Over 200 shared test vectors, 120 of them invalid inputs, run in CI for every implementation.",
  },
  {
    title: "Convert at the boundary",
    body: "Keep UUID columns in your database and show uuid58 in URLs, APIs, and logs. Conversion is lossless both ways, so you can change where each form lives at any time.",
  },
];

/** Other ways to shorten or replace UUIDs, for the comparison table. */
const alternatives = [
  {
    name: "uuid58",
    length: "22",
    uuid: "Yes",
    notes: "Bitcoin Base58, fixed length, sortable, one spec across languages.",
  },
  {
    name: "Standard UUID",
    length: "36",
    uuid: "Yes",
    notes:
      "Long, and the hyphens stop a double-click from selecting the whole ID.",
  },
  {
    name: "short-uuid (npm)",
    length: "22",
    uuid: "Yes",
    notes:
      "Flickr Base58 by default: a different alphabet order, so its strings differ from uuid58.",
  },
  {
    name: "shortuuid (Python)",
    length: "22",
    uuid: "Yes",
    notes: "A 57-character alphabet; its strings differ from uuid58.",
  },
  {
    name: "slugid",
    length: "22",
    uuid: "Yes",
    notes: "URL-safe Base64, so IDs can contain - and _.",
  },
  {
    name: "ULID",
    length: "26",
    uuid: "No",
    notes:
      "Its own format (Crockford Base32), 128-bit compatible with UUID but written differently.",
  },
  {
    name: "Nano ID",
    length: "21",
    uuid: "No",
    notes: "Random IDs, not UUIDs. Nothing to convert back to.",
  },
  {
    name: "Firestore auto-ID",
    length: "20",
    uuid: "No",
    notes:
      "Random alphanumeric IDs from the Firestore SDKs. Not sortable, nothing to convert back.",
  },
  {
    name: "Sqids",
    length: "Varies",
    uuid: "No",
    notes:
      "Encodes integers such as database row IDs, not UUIDs. Length grows with the number.",
  },
];

const faqs = [
  {
    question: "Will the format change?",
    answer:
      "No. Spec 1.1.0 fixes the alphabet, the padding, and the accepted inputs. Any change that would alter an encoded string needs a new major version of the spec, and every implementation is tested against the same versioned test vectors.",
  },
  {
    question: "Does it work with UUIDv7?",
    answer:
      "Yes. uuid58 encodes any 128-bit UUID, and strings sort in the same order as the UUIDs, so UUIDv7 IDs stay time-ordered when sorted as strings.",
  },
  {
    question: "Can I use uuid58 for Firestore document IDs?",
    answer:
      "Yes. uuid58 strings meet Firestore's document ID rules. Use random (v4) UUIDs: Firestore advises against sequential IDs, which can cause write hotspots. If you later move to a relational database, decode each ID into a UUID column; references between records carry over as they are.",
  },
  {
    question:
      "I found a 22-character ID like XDY9dmBbcMBXqcRvYw8xJ2. Is it uuid58?",
    answer:
      "If it uses only Base58 characters (no 0, O, I, or l) and decodes in the converter above, it is likely a uuid58-encoded UUID.",
  },
];

/** A button that copies `text` and briefly shows the result. */
function CopyButton(props: {
  text: () => string;
  label?: string;
  class?: string;
}) {
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
      class={props.class ?? "copy"}
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
            <div class="field-head">
              <label for={`${field.key}-input`}>
                {field.label}
                <span>{field.hint}</span>
              </label>
              <CopyButton
                class="copy-link"
                text={() => conversion()[field.key]}
                label={`Copy ${field.label}`}
              />
            </div>
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
          Paste a UUID (with or without hyphens) or a uuid58 string to convert
          it. Generate makes a random v4 UUID with{" "}
          <code>crypto.getRandomValues()</code>. Everything runs in your
          browser; nothing is sent anywhere.
        </p>
      </div>
    </div>
  );
}

function Samples(props: { values: () => Pair }) {
  const [selected, setSelected] = createSignal(samples[0]!.id);

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
              aria-controls={`sample-panel-${s.id}`}
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
      {/* Every panel is rendered, with all but the selected one hidden, so the
          prerendered page carries the install command and code for every
          language, not just the first. */}
      <For each={samples}>
        {(sample) => (
          <div
            id={`sample-panel-${sample.id}`}
            class="sample-panel"
            role="tabpanel"
            aria-labelledby={`tab-${sample.id}`}
            hidden={selected() !== sample.id}
          >
            <Show when={sample.note}>
              {(note) => <p class="sample-note">{note()}</p>}
            </Show>
            <div class="code-block">
              <pre>
                <code
                  class="language-shellscript"
                  innerHTML={highlighted.samples[sample.id]!.install}
                />
              </pre>
              <CopyButton
                text={() => sample.install}
                label={`Copy ${sample.label} install command`}
              />
            </div>
            <div class="code-block">
              <pre>
                <code
                  class={`language-${sample.language}`}
                  innerHTML={fill(
                    highlighted.samples[sample.id]!.code,
                    props.values(),
                  )}
                />
              </pre>
              <CopyButton
                text={() => sample.code(props.values())}
                label={`Copy ${sample.label} code sample`}
              />
            </div>
            <p class="links">
              <a href={sample.docs}>{sample.label} documentation</a>
              <For each={sample.registries}>
                {(registry) => <a href={registry.href}>{registry.label}</a>}
              </For>
            </p>
          </div>
        )}
      </For>
    </div>
  );
}

function CommandLine(props: { values: () => Pair }) {
  const [selected, setSelected] = createSignal(installMethods[0]!.id);
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
              aria-controls={`install-panel-${m.id}`}
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
      <For each={installMethods}>
        {(method) => (
          <div
            id={`install-panel-${method.id}`}
            class="sample-panel"
            role="tabpanel"
            aria-labelledby={`install-tab-${method.id}`}
            hidden={selected() !== method.id}
          >
            <div class="code-block">
              <pre>
                <code
                  class="language-shellscript"
                  innerHTML={highlighted.install[method.id]!}
                />
              </pre>
              <CopyButton
                text={() => method.command}
                label={`Copy ${method.label} install command`}
              />
            </div>
            <p class="sample-note">{method.note}</p>
          </div>
        )}
      </For>
      <p class="sample-note">
        Prebuilt binaries for macOS, Linux, and Windows are on{" "}
        <a href={cliReleases}>GitHub Releases</a>. The CLI ships with the next
        Go release; until then, only the Nix flake installs it.
      </p>

      <h3>Try without installing</h3>
      <p>
        With Nix, <code>nix run</code> builds the CLI and runs it on the spot,
        leaving nothing installed. Put the command and its arguments after{" "}
        <code>--</code>.
      </p>
      <div class="code-block">
        <pre>
          <code class="language-shellscript" innerHTML={highlighted.try} />
        </pre>
        <CopyButton text={() => tryCommand} label="Copy nix run command" />
      </div>

      <h3>Usage</h3>
      <p>
        Each command takes values as arguments, or reads one per line from
        standard input when there are none, so it fits in a pipeline. Every
        input is processed, and each invalid one is reported on standard error
        with its error kind.
      </p>
      <div class="code-block">
        <pre>
          <code
            class="language-shellsession"
            innerHTML={fill(highlighted.usage, props.values())}
          />
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

export function App() {
  // Start from the fixed sample so the prerendered HTML and the first client
  // render agree, then switch to a fresh random pair once the page is live.
  const initial = { encoded: SAMPLE_UUID58, decoded: SAMPLE_UUID };
  const [conversion, setConversion] = createSignal<ConversionState>({
    ...initial,
    error: undefined,
    valid: initial,
  });
  onMount(() => {
    const pair = newPair();
    setConversion({ ...pair, error: undefined, valid: pair });
  });

  return (
    <>
      <header class="topbar">
        <div class="container topbar-inner">
          <a class="brand" href="./">
            uuid58
          </a>
          <nav aria-label="Main">
            <a href="#playground">Converter</a>
            <a href="#install">Install</a>
            <a href="#cli">CLI</a>
            <a href={SPEC}>Spec</a>
            <a href={REPO}>GitHub</a>
          </nav>
        </div>
      </header>

      <main>
        <section class="hero container">
          <h1>Shorten UUIDs to 22 characters.</h1>
          <p class="lead">
            uuid58 turns a 36-character UUID into a 22-character Base58 string,
            and back. It is safe in URLs, sorts in the same order as the UUID,
            and leaves out look-alike characters (0, O, I, l).
          </p>
          <p class="lead">
            The format is fixed by a stable, versioned spec and checked by over
            200 shared test vectors, so every implementation (JavaScript, Go,
            Python, Rust, PostgreSQL, and more) produces the same string, today
            and in future releases.
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
            <a class="button" href={SPEC}>
              Read the spec
            </a>
          </div>
        </section>

        <section id="playground" class="container">
          <h2>UUID ⇄ Base58 converter</h2>
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

        <section id="compare" class="container">
          <h2>How uuid58 compares</h2>
          <div class="table-scroll">
            <table class="compare-table">
              <thead>
                <tr>
                  <th scope="col">Option</th>
                  <th scope="col">Length</th>
                  <th scope="col">Still a UUID?</th>
                  <th scope="col">Notes</th>
                </tr>
              </thead>
              <tbody>
                <For each={alternatives}>
                  {(option) => (
                    <tr class={option.name === "uuid58" ? "self" : undefined}>
                      <th scope="row">{option.name}</th>
                      <td>{option.length}</td>
                      <td>{option.uuid}</td>
                      <td>{option.notes}</td>
                    </tr>
                  )}
                </For>
              </tbody>
            </table>
          </div>
          <p class="sample-note">
            Pick uuid58 when you already use UUIDs (or want to), need them short
            in URLs and APIs, and want every service and language to agree on
            the string.
          </p>
        </section>

        <section id="install" class="container">
          <h2>Libraries for every language</h2>
          <p>
            Each library encodes UUIDs as uuid58 strings and decodes them back.
            All follow <a href={SPEC}>the uuid58 specification</a>{" "}
            {SPEC_VERSION} and pass{" "}
            <a href={`${REPO}/blob/main/spec/vectors.json`}>its test vectors</a>
            . The samples below use the values from the converter.
          </p>
          <Samples values={() => conversion().valid} />
        </section>

        <section id="cli" class="container">
          <h2>Command line</h2>
          <p>
            <code>uuid58</code> is a small command-line tool built on the Go
            implementation: a single static binary with no dependencies. The
            example uses the values from the converter.
          </p>
          <CommandLine values={() => conversion().valid} />
        </section>
        <section id="faq" class="container faq">
          <h2>FAQ</h2>
          <For each={faqs}>
            {(faq) => (
              <details>
                <summary>{faq.question}</summary>
                <p>{faq.answer}</p>
              </details>
            )}
          </For>
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

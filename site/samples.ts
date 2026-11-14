// Code samples for each uuid58 implementation, filled in with the values
// currently shown in the playground.

export type Sample = {
  id: string;
  label: string;
  /** Language name for the code block's class (no highlighting library). */
  language: string;
  install: string;
  code: (values: { encoded: string; decoded: string }) => string;
  docs: string;
  /** Where the package is published. */
  registries: { label: string; href: string }[];
};

const repo = "https://github.com/nakanoasaservice/uuid58";

export const samples: Sample[] = [
  {
    id: "js",
    label: "JavaScript",
    language: "typescript",
    install: "npm i @nakanoaas/uuid58",
    code: ({
      encoded,
      decoded,
    }) => `import { uuid58, uuid58Decode, uuid58Encode } from "@nakanoaas/uuid58";

uuid58Encode("${decoded}");
// => "${encoded}"

uuid58Decode("${encoded}");
// => "${decoded}"

uuid58(); // a new random UUID, encoded`,
    docs: `${repo}/tree/main/js#readme`,
    registries: [
      { label: "npm", href: "https://www.npmjs.com/package/@nakanoaas/uuid58" },
      { label: "JSR", href: "https://jsr.io/@nakanoaas/uuid58" },
    ],
  },
  {
    id: "go",
    label: "Go",
    language: "go",
    install: "go get github.com/nakanoasaservice/uuid58/go",
    code: ({
      encoded,
      decoded,
    }) => `import uuid58 "github.com/nakanoasaservice/uuid58/go"

s, err := uuid58.Encode("${decoded}")
// s == "${encoded}"

u, err := uuid58.Decode("${encoded}")
// u == "${decoded}"`,
    docs: `${repo}/tree/main/go#readme`,
    registries: [
      {
        label: "pkg.go.dev",
        href: "https://pkg.go.dev/github.com/nakanoasaservice/uuid58/go",
      },
    ],
  },
  {
    id: "python",
    label: "Python",
    language: "python",
    install: "pip install uuid58",
    code: ({ encoded, decoded }) => `import uuid58

uuid58.encode("${decoded}")
# '${encoded}'

uuid58.decode("${encoded}")
# '${decoded}'`,
    docs: `${repo}/tree/main/python#readme`,
    registries: [{ label: "PyPI", href: "https://pypi.org/project/uuid58/" }],
  },
  {
    id: "rust",
    label: "Rust",
    language: "rust",
    install: "cargo add uuid58",
    code: ({
      encoded,
      decoded,
    }) => `let id = uuid58::encode_uuid_str("${decoded}")?;
assert_eq!(id, "${encoded}");

let uuid = uuid58::decode_to_uuid_string("${encoded}")?;
assert_eq!(uuid, "${decoded}");`,
    docs: `${repo}/tree/main/rust#readme`,
    registries: [
      { label: "crates.io", href: "https://crates.io/crates/uuid58" },
    ],
  },
  {
    id: "java",
    label: "Java",
    language: "java",
    install: `implementation("io.github.nakanoasaservice:uuid58:0.1.0")`,
    code: ({
      encoded,
      decoded,
    }) => `import io.github.nakanoasaservice.uuid58.Uuid58;

Uuid58.encode("${decoded}");
// "${encoded}"

Uuid58.decode("${encoded}");
// "${decoded}"`,
    docs: `${repo}/tree/main/java#readme`,
    registries: [
      {
        label: "Maven Central",
        href: "https://central.sonatype.com/artifact/io.github.nakanoasaservice/uuid58",
      },
    ],
  },
  {
    id: "kotlin",
    label: "Kotlin",
    language: "kotlin",
    install: `implementation("io.github.nakanoasaservice:uuid58:0.1.0")`,
    code: ({
      encoded,
      decoded,
    }) => `import io.github.nakanoasaservice.uuid58.Uuid58

Uuid58.encode("${decoded}")
// "${encoded}"

Uuid58.decode("${encoded}")
// "${decoded}"`,
    docs: `${repo}/tree/main/java#readme`,
    registries: [
      {
        label: "Maven Central",
        href: "https://central.sonatype.com/artifact/io.github.nakanoasaservice/uuid58",
      },
    ],
  },
  {
    id: "swift",
    label: "Swift",
    language: "swift",
    install: `.package(url: "https://github.com/nakanoasaservice/uuid58-swift.git", from: "0.1.0")`,
    code: ({ encoded, decoded }) => `import UUID58

try uuid58Encode("${decoded}")
// "${encoded}"

try uuid58Decode("${encoded}")
// "${decoded}"`,
    docs: "https://github.com/nakanoasaservice/uuid58-swift#readme",
    registries: [],
  },
];

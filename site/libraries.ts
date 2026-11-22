// Library install commands and code examples for each language.

/**
 * The fixed UUID / uuid58 pair used in the library examples and as the page's initial converter values.
 * highlight.ts fills it into the highlighted HTML at build time.
 */
export const examplePair = {
  encoded: "XDY9dmBbcMBXqcRvYw8xJ2",
  decoded: "f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf",
};

export type Library = {
  id: string;
  label: string;
  /** Shiki language for the code sample, highlighted at build time. */
  language: string;
  install: string;
  code: string;
  docs: string;
  /** Where the package is published. */
  registries: { label: string; href: string }[];
  /** Shown above the install command, such as before the first release. */
  note?: string;
};

const repo = "https://github.com/nakanoasaservice/uuid58";

export const libraries: Library[] = [
  {
    id: "js",
    label: "JavaScript",
    language: "typescript",
    install: "npm i @nakanoaas/uuid58",
    code: `import { uuid58, uuid58Decode, uuid58Encode } from "@nakanoaas/uuid58";

uuid58Encode("${examplePair.decoded}");
// => "${examplePair.encoded}"

uuid58Decode("${examplePair.encoded}");
// => "${examplePair.decoded}"

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
    code: `import uuid58 "github.com/nakanoasaservice/uuid58/go"

s, err := uuid58.Encode("${examplePair.decoded}")
// s == "${examplePair.encoded}"

u, err := uuid58.Decode("${examplePair.encoded}")
// u == "${examplePair.decoded}"`,
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
    code: `import uuid58

uuid58.encode("${examplePair.decoded}")
# '${examplePair.encoded}'

uuid58.decode("${examplePair.encoded}")
# '${examplePair.decoded}'`,
    docs: `${repo}/tree/main/python#readme`,
    registries: [{ label: "PyPI", href: "https://pypi.org/project/uuid58/" }],
  },
  {
    id: "rust",
    label: "Rust",
    language: "rust",
    install: "cargo add uuid58",
    code: `let id = uuid58::encode_uuid_str("${examplePair.decoded}")?;
assert_eq!(id, "${examplePair.encoded}");

let uuid = uuid58::decode_to_uuid_string("${examplePair.encoded}")?;
assert_eq!(uuid, "${examplePair.decoded}");`,
    docs: `${repo}/tree/main/rust#readme`,
    registries: [
      { label: "crates.io", href: "https://crates.io/crates/uuid58" },
    ],
  },
  {
    id: "java",
    label: "Java",
    language: "java",
    install: `implementation("io.github.nakanoasaservice:uuid58:0.1.1")`,
    code: `import io.github.nakanoasaservice.uuid58.Uuid58;

Uuid58.encode("${examplePair.decoded}");
// "${examplePair.encoded}"

Uuid58.decode("${examplePair.encoded}");
// "${examplePair.decoded}"`,
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
    install: `implementation("io.github.nakanoasaservice:uuid58:0.1.1")`,
    code: `import io.github.nakanoasaservice.uuid58.Uuid58

Uuid58.encode("${examplePair.decoded}")
// "${examplePair.encoded}"

Uuid58.decode("${examplePair.encoded}")
// "${examplePair.decoded}"`,
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
    code: `import UUID58

try uuid58Encode("${examplePair.decoded}")
// "${examplePair.encoded}"

try uuid58Decode("${examplePair.encoded}")
// "${examplePair.decoded}"`,
    docs: "https://github.com/nakanoasaservice/uuid58-swift#readme",
    registries: [],
  },
  {
    id: "csharp",
    label: "C#",
    language: "csharp",
    install: "dotnet add package Uuid58",
    code: `using NakanoAsAService.Uuid58;

Uuid58.EncodeUuidString("${examplePair.decoded}");
// "${examplePair.encoded}"

Uuid58.Decode("${examplePair.encoded}");
// "${examplePair.decoded}"`,
    docs: `${repo}/tree/main/dotnet#readme`,
    registries: [
      { label: "NuGet", href: "https://www.nuget.org/packages/Uuid58" },
    ],
  },
  {
    id: "php",
    label: "PHP",
    language: "php",
    install: "composer require nakanoaas/uuid58",
    code: `use NakanoAsAService\\Uuid58\\Uuid58;

Uuid58::encode('${examplePair.decoded}');
// '${examplePair.encoded}'

Uuid58::decode('${examplePair.encoded}');
// '${examplePair.decoded}'`,
    docs: "https://github.com/nakanoasaservice/uuid58-php#readme",
    registries: [
      {
        label: "Packagist",
        href: "https://packagist.org/packages/nakanoaas/uuid58",
      },
    ],
  },
  {
    id: "ruby",
    label: "Ruby",
    language: "ruby",
    install: "bundle add uuid58",
    code: `require "uuid58"

Uuid58.encode("${examplePair.decoded}")
# => "${examplePair.encoded}"

Uuid58.decode("${examplePair.encoded}")
# => "${examplePair.decoded}"`,
    docs: `${repo}/tree/main/ruby#readme`,
    registries: [
      { label: "RubyGems", href: "https://rubygems.org/gems/uuid58" },
    ],
  },
  {
    id: "dart",
    label: "Dart",
    language: "dart",
    install: "dart pub add uuid58",
    code: `import 'package:uuid58/uuid58.dart';

uuid58Encode('${examplePair.decoded}');
// '${examplePair.encoded}'

uuid58Decode('${examplePair.encoded}');
// '${examplePair.decoded}'`,
    docs: `${repo}/tree/main/dart#readme`,
    registries: [{ label: "pub.dev", href: "https://pub.dev/packages/uuid58" }],
  },
  {
    id: "elixir",
    label: "Elixir",
    language: "elixir",
    install: `{:uuid58, "~> 0.1.0"}`,
    code: `{:ok, s} = Uuid58.encode("${examplePair.decoded}")
# s == "${examplePair.encoded}"

{:ok, u} = Uuid58.decode("${examplePair.encoded}")
# u == "${examplePair.decoded}"`,
    docs: `${repo}/tree/main/elixir#readme`,
    registries: [{ label: "Hex", href: "https://hex.pm/packages/uuid58" }],
    note: unreleased,
  },
  {
    id: "postgres",
    label: "PostgreSQL",
    language: "sql",
    install: `curl -fsSL https://raw.githubusercontent.com/nakanoasaservice/uuid58/main/postgres/uuid58.sql | psql`,
    code: `SELECT uuid58_encode('${examplePair.decoded}'::uuid);
-- ${examplePair.encoded}

SELECT uuid58_decode('${examplePair.encoded}');
-- ${examplePair.decoded}`,
    docs: `${repo}/tree/main/postgres#readme`,
    registries: [],
  },
];

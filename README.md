# uuid58

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

uuid58 encodes a UUID as a fixed 22-character Base58 string, using the Bitcoin
alphabet. The result is shorter than the usual 36-character form, safe to use
in URLs, and free of look-alike characters (`0`, `O`, `I`, `l`).

```text
f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf  ⇄  XDY9dmBbcMBXqcRvYw8xJ2
```

Encoded strings sort in the same order as the UUIDs they encode.

[Try it in the Playground](https://nakanoasaservice.github.io/uuid58-playground/).

## Specification

[`spec/SPEC.md`](spec/SPEC.md) defines the format, and
[`spec/vectors.json`](spec/vectors.json) holds test vectors that every
implementation must pass. The spec is a draft until the first implementations
in other languages are done (see [ROADMAP.md](ROADMAP.md)).

## Implementations

| Language              | Directory    | Package                                                                                                                   |
| --------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------- |
| JavaScript/TypeScript | [`js/`](js/) | [`@nakanoaas/uuid58`](https://www.npmjs.com/package/@nakanoaas/uuid58) on npm and [JSR](https://jsr.io/@nakanoaas/uuid58) |

Go, Python, Rust, and Java/Kotlin are planned.

## Releases

Each implementation is released on its own, with tags prefixed by its
directory, such as `js/v1.2.3`.

## License

MIT License - see the [LICENSE](LICENSE) file for details

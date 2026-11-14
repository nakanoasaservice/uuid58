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
implementation must pass. The current version of the spec is 1.0.0.

## Implementations

| Language              | Directory                                                        | Package                                                                                                                   |
| --------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| JavaScript/TypeScript | [`js/`](js/)                                                     | [`@nakanoaas/uuid58`](https://www.npmjs.com/package/@nakanoaas/uuid58) on npm and [JSR](https://jsr.io/@nakanoaas/uuid58) |
| Go                    | [`go/`](go/)                                                     | `github.com/nakanoasaservice/uuid58/go`                                                                                   |
| Python                | [`python/`](python/)                                             | `uuid58` on PyPI                                                                                                          |
| Rust                  | [`rust/`](rust/)                                                 | `uuid58` on crates.io                                                                                                     |
| Java/Kotlin           | [`java/`](java/)                                                 | `io.github.nakanoasaservice:uuid58` on Maven Central                                                                      |
| Swift                 | [uuid58-swift](https://github.com/nakanoasaservice/uuid58-swift) | Swift Package Manager                                                                                                     |

The Go, Python, Rust, Java/Kotlin, and Swift implementations are not released
yet. Swift has its own repository because Swift Package Manager expects
`Package.swift` at the root of a repository.
The JavaScript package 1.x accepts hyphens anywhere in its input, which the
spec does not allow; 2.0 will follow the spec.

## Releases

Each implementation is released on its own, with tags prefixed by its
directory, such as `js/v1.2.3`. Swift releases are plain version tags in
uuid58-swift.

## License

MIT License - see the [LICENSE](LICENSE) file for details

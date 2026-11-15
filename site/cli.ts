// Content for the command-line section: install methods, a usage example
// filled in with the playground values, and the list of commands.

const repo = "https://github.com/nakanoasaservice/uuid58";

export const cliDocs = `${repo}/tree/main/go#command-line-tool`;
export const cliReleases = `${repo}/releases`;

export type InstallMethod = {
  id: string;
  label: string;
  command: string;
  /** One line under the command. */
  note: string;
};

export const installMethods: InstallMethod[] = [
  {
    id: "homebrew",
    label: "Homebrew",
    command: "brew install nakanoasaservice/tap/uuid58",
    note: "macOS and Linux. Installs a prebuilt binary.",
  },
  {
    id: "nix",
    label: "Nix",
    command: "nix profile install github:nakanoasaservice/uuid58",
    note: "Builds from source. To try it without installing, run nix run github:nakanoasaservice/uuid58 -- gen.",
  },
  {
    id: "go",
    label: "Go",
    command:
      "go install github.com/nakanoasaservice/uuid58/go/cmd/uuid58@latest",
    note: "Needs Go 1.26 or later. Installs into $(go env GOPATH)/bin.",
  },
];

export function usageExample({
  encoded,
  decoded,
}: {
  encoded: string;
  decoded: string;
}): string {
  return `$ uuid58 encode ${decoded}
${encoded}

$ uuid58 decode ${encoded}
${decoded}

$ uuid58 validate ${encoded} abc
uuid58 validate: "abc": invalid_length

$ uuid58 gen -n 2
JSGfCL3atpZzP7Qh5Hrt3C
SaBF5eq63TPKCD46a2Gecc

$ cut -d, -f1 users.csv | uuid58 encode > ids.txt`;
}

export const commands: { usage: string; description: string }[] = [
  {
    usage: "encode [uuid ...]",
    description:
      "UUID to uuid58. Accepts the hyphenated form and 32 hex digits, in either case.",
  },
  {
    usage: "decode [uuid58 ...]",
    description: "uuid58 to a lowercase hyphenated UUID.",
  },
  {
    usage: "validate [uuid58 ...]",
    description:
      "Exits with 0 if every input is a valid uuid58, and reports each invalid one. Alias: check.",
  },
  {
    usage: "gen [-n count] [-uuid]",
    description:
      "New random version 4 UUIDs as uuid58. -uuid adds the UUID after a tab. Alias: new.",
  },
  {
    usage: "--version, --help",
    description: "Prints the version or the usage.",
  },
];

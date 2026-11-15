{
  description = "uuid58: convert UUIDs to and from a 22-character Base58 encoding";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.uuid58;

        # The CLI in go/cmd/uuid58. The flake cannot see git tags, so the
        # version is the commit date and revision; tagged releases are on
        # Homebrew and GitHub Releases.
        uuid58 = pkgs.buildGoModule {
          pname = "uuid58";
          version = "0-unstable-${builtins.substring 0 8 self.lastModifiedDate}";

          # go/ plus spec/, which the CLI tests read.
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./go
              ./spec
            ];
          };
          modRoot = "go";
          subPackages = [ "cmd/uuid58" ];
          vendorHash = null; # standard library only

          env.CGO_ENABLED = "0";
          ldflags = [
            "-s"
            "-w"
            "-X main.version=${self.shortRev or self.dirtyShortRev or "dirty"}"
          ];

          meta = {
            description = "Convert UUIDs to and from uuid58, a 22-character Base58 encoding";
            homepage = "https://github.com/nakanoasaservice/uuid58";
            license = pkgs.lib.licenses.mit;
            mainProgram = "uuid58";
          };
        };
      });

      checks = forAllSystems (pkgs: {
        uuid58 = self.packages.${pkgs.stdenv.hostPlatform.system}.uuid58;
      });
    };
}

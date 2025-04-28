import { build, emptyDir } from "@deno/dnt";

await emptyDir("./dist");

interface Config {
  name: string;
  version: string;
  license: string;
  compilerOptions: { [key: string]: boolean };
}

const jsrJson = await Deno.readTextFile("./deno.json");
const config: Config = JSON.parse(jsrJson);

await build({
  entryPoints: ["./index.ts"],
  outDir: "./dist",
  shims: {
    deno: true,
  },

  test: false,
  compilerOptions: config.compilerOptions,

  package: {
    // package.json properties
    name: config.name,
    version: config.version,
    license: config.license,
    description: "A Base58-encoded UUID encoder and decoder.",
    repository: {
      type: "git",
      url: "git://github.com/nakanoasaservice/uuid58.git",
    },
    bugs: {
      url: "https://github.com/nakanoasaservice/uuid58/issues",
    },
  },
  postBuild() {
    // steps to run after building and before running the tests
    Deno.copyFileSync("LICENSE", "dist/LICENSE");
    Deno.copyFileSync("README.md", "dist/README.md");
  },
});

import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

const entries = [
  {
    entry: join(__dirname, "get-ports/get-ports.ts"),
    outfile: join(__dirname, "dist/get-ports/get-ports.js"),
  },
];

for (const { entry, outfile } of entries) {
  await build({ entryPoints: [entry], bundle: true, format: "esm", outfile });
  console.log(`built: ${outfile}`);
}

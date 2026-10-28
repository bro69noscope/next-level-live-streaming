import { spawnSync } from "node:child_process";
import { concurrently } from "concurrently";

const projects = {
  "alerts-overlays": {
    tsconfig: "external/html/alerts-overlays",
    serve: ".venv\\Scripts\\python external\\html\\alerts-overlays\\server.py",
  },
  streamfeed: {
    tsconfig: "external/StreamFeedApp",
  },
};

const tasks = {
  build: (p) => p.tsconfig && `tsc -b ${p.tsconfig}`,
  watch: (p) => p.tsconfig && `tsc -b ${p.tsconfig} --watch`,
  serve: (p) => p.serve,
  weztab: (p, name) =>
    p.serve &&
    [
      "wezterm cli spawn",
      `--cwd "${process.cwd()}"`,
      "-- pwsh -NoExit -Command",
      `"node scripts/tasks.mjs serve ${name}"`,
    ].join(" "),
};

const composite = { dev: ["serve", "watch"] };

// argv: [node path, script path, ...user args]; slice(2) keeps user args only
// usage: node scripts/tasks.mjs <task> [project|all]
// e.g.: node scripts/tasks.mjs build alerts-overlays
const [task, target = "all"] = process.argv.slice(2);

const known = [...Object.keys(tasks), ...Object.keys(composite)];

if (!known.includes(task)) {
  console.error(`unknown task "${task}". options: ${known.join(", ")}`);
  process.exit(1);
}

const subtasks = composite[task] ?? [task];
const names = target === "all" ? Object.keys(projects) : [target];
const commandsWithName = names
  .filter((n) => projects[n])
  .flatMap((n) =>
    subtasks.map((t) => ({
      name: `${n}:${t}`,
      command: tasks[t](projects[n], n),
    })),
  )
  .filter((c) => c.command);

if (!commandsWithName.length) {
  console.error(`nothing to run for "${task} ${target}"`);
  process.exit(1);
}

try {
  await concurrently(commandsWithName, { killOthers: ["failure"] }).result;
} catch {
  process.exit(1);
}

if (task === "build") {
  const r = spawnSync(
    "node",
    ["external/common/helpers/js/build-js-helpers.mjs"],
    {
      stdio: "inherit",
    },
  );
  process.exit(r.status ?? 1);
}

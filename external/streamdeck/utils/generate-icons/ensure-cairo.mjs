// scripts/ensure-cairo.mjs
import { execSync } from "node:child_process";

function has(cmd) {
  try {
    execSync(cmd, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function hasCairoDll() {
  // names account for conda miniforge3 and Windows GTK installations
  return has("where.exe cairo.dll") || has("where.exe libcairo-2.dll");
}

const condaBin = `${process.env.USERPROFILE}\\miniforge3\\Library\\bin`;

if (!hasCairoDll()) {
  console.log("libcairo-2.dll not found.");

  if (!has("where.exe conda")) {
    console.warn(
      "conda not found. Install Miniforge first: " +
        "winget install --id CondaForge.Miniforge3 -e " +
        "then restart your shell and re-run `npm run setup:cairo`.",
    );
    process.exit(1);
  }

  console.log("Installing cairo via conda-forge...");
  execSync("conda install -c conda-forge cairo -y", { stdio: "inherit" });
  console.log(
    `Cairo installed. Ensure "${condaBin}" is on your PATH, then restart your shell.`,
  );
} else {
  console.log("libcairo already present.");
}

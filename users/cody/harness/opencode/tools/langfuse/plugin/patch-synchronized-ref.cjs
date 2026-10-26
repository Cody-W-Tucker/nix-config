"use strict";

// OpenCode 2.1.1 (Bun) evaluates Effect.runSync(SynchronizedRef.make(...))
// in Langfuse 0.6.0 as undefined. The constructor itself is synchronous, so
// replace that expression with Effect's documented synchronous constructor.

const fs = require("fs");
const path = require("path");

const EXPECTED_VERSION = "0.6.0";
const ORIGINAL = 'runSync$1(make({ _tag: "Empty" }))';
const REPLACEMENT = 'makeUnsafe({ _tag: "Empty" })';
const SENTINEL = "/* langfuse-synchronized-ref-patch applied */";

function fail(message) {
  console.error(`langfuse synchronized-ref patch: FAIL: ${message}`);
  process.exit(1);
}

const targetDir = process.argv[2];
if (!targetDir) fail("missing <managed-plugin-dir> argument");

const packageDir = path.join(
  path.resolve(targetDir),
  "node_modules",
  "@langfuse",
  "opencode-observability-plugin"
);
const packageJsonPath = path.join(packageDir, "package.json");
let packageJson;
try {
  packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
} catch (error) {
  fail(`cannot read ${packageJsonPath}: ${error.message}`);
}
if (packageJson.version !== EXPECTED_VERSION) {
  fail(`expected upstream ${EXPECTED_VERSION}, found ${packageJson.version}`);
}

const runtimeFiles = fs
  .readdirSync(path.join(packageDir, "dist"))
  .filter((name) => /^runtime-.*\.js$/.test(name));
if (runtimeFiles.length !== 1) {
  fail(`expected one runtime bundle, found: ${runtimeFiles.join(", ") || "none"}`);
}

const runtimePath = path.join(packageDir, "dist", runtimeFiles[0]);
let source = fs.readFileSync(runtimePath, "utf8");
if (source.includes(SENTINEL)) {
  if (!source.includes(REPLACEMENT)) fail("sentinel present but replacement is absent");
  console.error(`langfuse synchronized-ref patch: already applied to ${runtimeFiles[0]}.`);
  process.exit(0);
}

const occurrences = source.split(ORIGINAL).length - 1;
if (occurrences !== 1) {
  fail(`expected one unsafe initialization expression, found ${occurrences}`);
}

source = source.replace(ORIGINAL, `${REPLACEMENT} ${SENTINEL}`);
fs.writeFileSync(runtimePath, source, "utf8");
console.error(`langfuse synchronized-ref patch: patched ${runtimeFiles[0]}.`);

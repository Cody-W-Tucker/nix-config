// TEMPORARY workaround for upstream Langfuse no-op-tracer bug:
// https://github.com/langfuse/opencode-observability-plugin/issues/55
//
// `@langfuse/opencode-observability-plugin@0.5.2` bundles
// `dist/runtime-*.js` where `createLangfuseClient` builds `traceState`
// with `tracer: trace.getTracer(tracerName, PLUGIN_VERSION)` BEFORE
// `provider.register()` runs. A tracer acquired before registration is
// bound to the default Noop provider, so all spans are silently dropped
// even with a valid OTLP endpoint.
//
// This script defers tracer acquisition until immediately after provider
// registration: the literal becomes `tracer: void 0` and
// `traceState.tracer = trace.getTracer(...)` is assigned right after
// `provider.register()`. Safe because nothing reads `traceState.tracer`
// between the literal and registration (only `tracerName` strings are
// used there); spans start after the client is returned.
//
// The script is:
// - scoped: only touches the managed local plugin dir passed as argv[2]
//   (never the OpenCode npm cache),
// - assertive: verifies the expected upstream version + code shape before
//   patching, and fails loudly if the bundle no longer matches (which
//   likely means upstream fixed or refactored the bug),
// - idempotent: a sentinel comment plus a `.tracer-patch-applied` marker
//   make re-runs cheap no-ops.
//
// Usage: node patch-tracer.cjs <managed-plugin-dir>
// Exit 0: patched or already patched. Exit 1: unexpected code shape.
// REMOVAL CONDITION: delete with the rest of tools/langfuse/ once upstream
// ships a fixed release (see ../README.md).
"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const EXPECTED_VERSION = "0.5.2";
const SENTINEL = "/* langfuse-tracer-order-patch applied */";
const MARKER_FILE = ".tracer-patch-applied";

function fail(msg) {
  console.error(`langfuse tracer-order patch: FAIL: ${msg}`);
  process.exit(1);
}

function sha256(text) {
  return crypto.createHash("sha256").update(text, "utf8").digest("hex");
}

function main() {
  const targetDir = process.argv[2];
  if (!targetDir) fail("missing <managed-plugin-dir> argument");
  const resolved = path.resolve(targetDir);

  const pkgPath = path.join(
    resolved,
    "node_modules",
    "@langfuse",
    "opencode-observability-plugin",
    "package.json"
  );
  let pkg;
  try {
    pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  } catch (err) {
    fail(`cannot read upstream package.json at ${pkgPath}: ${err.message}`);
  }
  if (pkg.version !== EXPECTED_VERSION) {
    fail(
      `expected upstream version ${EXPECTED_VERSION}, found ${pkg.version}. ` +
        `Bundle shape may have changed; review the upstream fix and remove/refresh this workaround.`
    );
  }

  const distDir = path.join(
    resolved,
    "node_modules",
    "@langfuse",
    "opencode-observability-plugin",
    "dist"
  );
  let entries;
  try {
    entries = fs.readdirSync(distDir).filter((f) => /^runtime-.*\.js$/.test(f));
  } catch (err) {
    fail(`cannot list dist dir ${distDir}: ${err.message}`);
  }
  if (entries.length === 0) fail(`no dist/runtime-*.js bundle found in ${distDir}`);
  if (entries.length > 1) {
    fail(`expected exactly one dist/runtime-*.js bundle, found: ${entries.join(", ")}`);
  }
  const bundlePath = path.join(distDir, entries[0]);
  const markerPath = path.join(distDir, MARKER_FILE);

  let src = fs.readFileSync(bundlePath, "utf8");

  // Idempotent fast path: sentinel present -> verify the deferred
  // assignment now sits after provider registration.
  if (src.includes(SENTINEL)) {
    const tracerIdx = src.indexOf("trace.getTracer(");
    const registerIdx = src.search(/\.register\s*\(/);
    if (tracerIdx !== -1 && registerIdx !== -1 && tracerIdx > registerIdx) {
      fs.writeFileSync(markerPath, `${entries[0]}\n${sha256(src)}\n`, "utf8");
      console.error(`langfuse tracer-order patch: already applied to ${entries[0]}, verified.`);
      return;
    }
    fail(`sentinel present in ${entries[0]} but tracer/register order is not fixed; refusing to continue.`);
  }

  // Expected upstream buggy shape: exactly one trace.getTracer(...) call,
  // as a `tracer:` property of the traceState literal, appearing BEFORE
  // provider.register().
  const getTracerCount = src.split("trace.getTracer(").length - 1;
  if (getTracerCount === 0) {
    fail(
      `no "trace.getTracer(" call found in ${entries[0]}. ` +
        `Upstream likely refactored; review and remove/refresh this workaround.`
    );
  }
  if (getTracerCount > 1) {
    fail(
      `expected exactly one trace.getTracer( call, found ${getTracerCount} in ${entries[0]}. ` +
        `Refusing to guess which one to defer; review manually.`
    );
  }
  const propRe = /tracer:\s*trace\.getTracer\(([^)]*?)\)\s*,/;
  const propMatch = propRe.exec(src);
  if (!propMatch) {
    fail(
      `expected "tracer: trace.getTracer(...) property" not found in ${entries[0]}. ` +
        `Upstream likely refactored; review and remove/refresh this workaround.`
    );
  }
  const tracerArgs = propMatch[1].trim();

  // Holder object name: nearest `const <name> = {` before the property.
  const beforeProp = src.slice(Math.max(0, propMatch.index - 1000), propMatch.index);
  const holderMatch = /const\s+([A-Za-z_$][\w$]*)\s*=\s*\{[^]*$/.exec(beforeProp);
  if (!holderMatch) {
    fail(
      `cannot determine the traceState holder object for the tracer property in ${entries[0]}. ` +
        `Refusing to patch to avoid corrupting the bundle.`
    );
  }
  const holder = holderMatch[1];

  const registerRe = /([ \t]*)provider\.register\(\s*\)\s*;/;
  let registerMatch = registerRe.exec(src);
  if (!registerMatch) {
    const genericRe = /([ \t]*)([A-Za-z_$][\w$]*)\.register\(\s*\)\s*;/;
    const genericMatch = genericRe.exec(src);
    if (!genericMatch) {
      fail(
        `expected "provider.register()" call not found in ${entries[0]}. ` +
          `Upstream likely refactored; review and remove/refresh this workaround.`
      );
    }
    const windowStart = Math.max(0, genericMatch.index - 2000);
    if (!/TracerProvider/.test(src.slice(windowStart, genericMatch.index))) {
      fail(
        `nearest .register() call in ${entries[0]} is not near a TracerProvider; ` +
          `refusing to patch to avoid corrupting the bundle.`
      );
    }
    registerMatch = genericMatch;
  }
  if (!(propMatch.index < registerMatch.index)) {
    fail(
      `tracer acquisition already sits after provider registration in ${entries[0]}. ` +
        `Upstream may have fixed the bug; remove this workaround instead of patching.`
    );
  }

  // 1. Neutralize the early acquisition in the literal.
  const deferredProp =
    `tracer: void 0, /* langfuse-tracer-order-patch: acquisition deferred until after provider registration */`;
  src = src.slice(0, propMatch.index) + deferredProp + src.slice(propMatch.index + propMatch[0].length);

  // 2. Re-locate register (indices shifted) and assign right after it.
  const registerMatch2 = registerRe.exec(src) || /([ \t]*)([A-Za-z_$][\w$]*)\.register\(\s*\)\s*;/.exec(src);
  if (!registerMatch2) fail(`register() call vanished during patch of ${entries[0]}; aborting without writing.`);
  const indent = registerMatch2[1] || "\t\t";
  const insertAt = registerMatch2.index + registerMatch2[0].length;
  const acquisition = `\n${indent}${SENTINEL}\n${indent}${holder}.tracer = trace.getTracer(${tracerArgs});`;
  src = src.slice(0, insertAt) + acquisition + src.slice(insertAt);

  // Post-condition: tracer acquisition now after registration, sentinel kept.
  const tracerIdx = src.indexOf("trace.getTracer(");
  const registerIdx = src.search(/\.register\s*\(/);
  if (!(registerIdx !== -1 && tracerIdx > registerIdx && src.includes(SENTINEL))) {
    fail(`post-patch verification failed for ${entries[0]}; bundle left unmodified on disk.`);
  }

  fs.writeFileSync(bundlePath, src, "utf8");
  fs.writeFileSync(markerPath, `${entries[0]}\n${sha256(src)}\n`, "utf8");
  console.error(
    `langfuse tracer-order patch: patched ${entries[0]} (${holder}.tracer acquisition moved after provider registration).`
  );
}

main();

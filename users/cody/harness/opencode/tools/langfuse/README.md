# Langfuse observability plugin — TEMPORARY local workaround

Upstream issue: https://github.com/langfuse/opencode-observability-plugin/issues/55
(Open — no fixed release at time of writing.)

## Why this exists

`@langfuse/opencode-observability-plugin@0.5.2` resolves
`@opentelemetry/api@1.9.1`, but transitive `sdk-logs@3.0.0` requires
`@opentelemetry/api >=1.10.0`, so the bare npm spec fails at runtime.

## What it does

- Keeps a checked-in wrapper `plugin/package.json` pinning the exact
  upstream `0.5.2` tarball with an explicit npm `overrides` entry forcing
  `@opentelemetry/api@^1.10.0`, plus a managed forwarding entrypoint
  `plugin/index.ts` (selected via package.json `main`, the standard OpenCode
  V2 directory-plugin entrypoint mechanism) that default-exports the
  upstream plugin unchanged — a bare `package.json` alone is not loadable
  by OpenCode V2 directory-plugin resolution.
- `default.nix` materializes it to
  `~/.config/opencode/plugins/langfuse-observability` via a
  `home.activation` step, and registers
  that local path in `programs.opencode.settings.plugins`.
- Never touches the OpenCode npm cache.
- Secrets are untouched: Langfuse credentials still come from the SOPS
  `opencode-langfuse-env` template owned by `users/cody/harness/opencode/default.nix`.
- Repeatable: activation skips `npm install` when the target already matches
  the wrapper `package.json` and has `@opentelemetry/api >= 1.10.0`
  installed — no network on every activation.
- No-op-tracer patch: `plugin/patch-tracer.cjs` runs after every
  activation (fresh install or skip path — no network). The upstream
  `0.5.2` bundle (`dist/runtime-*.js`) calls `trace.getTracer(...)`
  before `NodeTracerProvider.register()`, so the tracer binds to the
  default Noop provider and zero spans reach the (valid) OTLP endpoint.
  The script asserts the expected `0.5.2` version plus the buggy
  getTracer-before-register shape, defers tracer acquisition until
  immediately after registration, and fails activation loudly if the
  bundle no longer matches (upstream fixed/refactored). Applied state is
  marked idempotently via a sentinel comment plus a
  `.tracer-patch-applied` marker beside the bundle, so re-runs verify
  without reinstalling. Scoped to the managed plugin dir — never mutates
  the OpenCode npm cache.

## Removal condition

When the upstream issue is closed with a fixed release that pins
`@opentelemetry/api >= 1.10.0` **and** acquires the tracer only after
provider registration (verified: bundled `dist/runtime-*.js` has no
`trace.getTracer(...)` before `NodeTracerProvider.register()`, spans
reach the OTLP endpoint):

1. Delete `users/cody/harness/opencode/tools/langfuse/`.
2. Drop the `./tools/langfuse` import in `users/cody/harness/opencode/default.nix`.
3. Restore the bare `@langfuse/opencode-observability-plugin@<fixed-version>`
   spec in `programs.opencode.settings.plugins`.

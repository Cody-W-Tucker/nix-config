# Langfuse observability plugin — TEMPORARY local workaround

Upstream issue: https://github.com/langfuse/opencode-observability-plugin/issues/55
(closed by 0.6.0). This wrapper keeps the upstream 0.6.0 dependency and
tracer fixes, with one compatibility patch for OpenCode 2.1.1's Bun runtime.

## Why this exists

The bare `@langfuse/opencode-observability-plugin@0.6.0` fails during plugin
setup on this machine with `self.semaphore.withPermit` on an undefined value.
The failing expression is `Effect.runSync(SynchronizedRef.make(...))`; the
bundle already includes `SynchronizedRef.makeUnsafe`, the synchronous form of
the same constructor.

## What it does

- Keeps a checked-in wrapper `plugin/package.json` pinning the exact upstream
  `0.6.0` tarball, plus a managed forwarding entrypoint
  `plugin/index.ts` (selected via package.json `main`, the same mechanism
  as the model-router `src/index.ts` main) that default-exports the
  upstream plugin unchanged — a bare `package.json` alone is not loadable
  by OpenCode V2 directory-plugin resolution.
- `default.nix` materializes it to
  `~/.config/opencode/plugins/langfuse-observability` via a
  `home.activation` step (same pattern as `../model-router`), and registers
  that local path in `programs.opencode.settings.plugins`.
- Never touches the OpenCode npm cache.
- Secrets are untouched: Langfuse credentials still come from the SOPS
  `opencode-langfuse-env` template owned by `users/cody/harness/opencode/default.nix`.
- Repeatable: activation skips `npm install` when the target matches the
  wrapper and contains the expected upstream version — no network on every
  activation.
- `plugin/patch-synchronized-ref.cjs` runs after every activation. It asserts
  upstream `0.6.0` and exactly one matching bundled expression, replacing it
  with `SynchronizedRef.makeUnsafe(...)`. It is idempotent and fails loudly
  if upstream refactors the code. The patch is scoped to the managed plugin
  directory and never mutates the OpenCode npm cache.

## Removal condition

When an upstream release loads successfully on the installed OpenCode version
and emits spans to the local Langfuse instance (including the dependency and
tracer fixes already present in 0.6.0):

1. Delete `users/cody/harness/opencode/tools/langfuse/`.
2. Drop the `./tools/langfuse` import in `users/cody/harness/opencode/default.nix`.
3. Restore the bare `@langfuse/opencode-observability-plugin@<fixed-version>`
   spec in `programs.opencode.settings.plugins`.

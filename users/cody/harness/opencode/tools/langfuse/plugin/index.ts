// TEMPORARY workaround for upstream Langfuse plugin bug:
// https://github.com/langfuse/opencode-observability-plugin/issues/55
//
// OpenCode V2 resolves a local directory plugin through the package.json
// `main` entrypoint. This managed forwarding module re-exports the upstream
// plugin's default export unchanged (it already carries both the v1 `server`
// hook and the v2 hooks), so the only behavioral delta versus the bare npm
// spec is the `@opentelemetry/api >=1.10.0` override declared in the sibling
// package.json.
//
// REMOVAL CONDITION: delete this file with the rest of
// `users/cody/harness/opencode/tools/langfuse/` once upstream ships a fixed
// release (see ./default.nix).
import langfusePlugin from "@langfuse/opencode-observability-plugin";

export default langfusePlugin;

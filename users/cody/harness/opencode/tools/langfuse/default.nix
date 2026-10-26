# TEMPORARY workaround for upstream Langfuse plugin bug:
# https://github.com/langfuse/opencode-observability-plugin/issues/55
#
# Upstream 0.6.0 fixes the former dependency and tracer-order failures, but on
# OpenCode 2.1.1 its Effect.runSync(SynchronizedRef.make(...)) expression
# produces an undefined ref. This wrapper replaces only that constructor with
# SynchronizedRef.makeUnsafe(...), which has the same intended initial state.
#
# REMOVAL CONDITION: delete this directory, drop the `./tools/langfuse`
# import, and restore the bare
# `@langfuse/opencode-observability-plugin@<fixed-version>` spec in
# `users/cody/harness/opencode/default.nix` once it loads successfully on the
# installed OpenCode version and emits spans to the local Langfuse instance.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Checked-in wrapper (./plugin/package.json + ./plugin/index.ts) that
  # depends on the exact upstream 0.6.0 tarball. patch-synchronized-ref.cjs
  # replaces the one failing initialization expression. index.ts is the OpenCode V2 entrypoint
  # (selected via package.json `main`) and only re-exports the upstream
  # default export. Kept next to this module per harness placement rules
  # (implementation files beside their Nix packaging).
  wrapperSrc = ./plugin;

  pluginPath = "${config.xdg.configHome}/opencode/plugins/langfuse-observability";

  # Node + npm used only at activation time to materialize node_modules
  # inside the managed plugin dir (never mutates the OpenCode npm cache).
  nodePkg = pkgs.nodejs;
in
{
  home.activation.opencodeLangfusePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    plugin_dir="${config.xdg.configHome}/opencode/plugins"
    target_dir="${pluginPath}"
    wrapper_src="${wrapperSrc}"
    PATH="${lib.getBin nodePkg}/bin:$PATH"

    mkdir -p "$plugin_dir"

    # Repeatable materialization: skip the network install when the target
    # already matches this wrapper and includes the asserted runtime patch.
    need_install=1
    if [ -f "$target_dir/package.json" ] && cmp -s "$wrapper_src/package.json" "$target_dir/package.json" \
       && [ -f "$target_dir/index.ts" ] && cmp -s "$wrapper_src/index.ts" "$target_dir/index.ts" \
       && [ -f "$target_dir/patch-synchronized-ref.cjs" ] && cmp -s "$wrapper_src/patch-synchronized-ref.cjs" "$target_dir/patch-synchronized-ref.cjs" \
       && [ -f "$target_dir/node_modules/@langfuse/opencode-observability-plugin/package.json" ]; then
      installed_version="$(node -p "require('$target_dir/node_modules/@langfuse/opencode-observability-plugin/package.json').version" 2>/dev/null || echo "")"
      [ "$installed_version" = "0.6.0" ] && need_install=0
    fi

    if [ "$need_install" -eq 0 ]; then
      echo "opencode langfuse plugin: already materialized (upstream $installed_version), skipping npm install." >&2
    else
      rm -rf "$target_dir"
      mkdir -p "$target_dir"
      cp "$wrapper_src/package.json" "$wrapper_src/index.ts" "$wrapper_src/patch-synchronized-ref.cjs" "$target_dir/"
      chmod u+w "$target_dir/package.json" "$target_dir/index.ts" "$target_dir/patch-synchronized-ref.cjs"
      # One network install per wrapper change; subsequent activations are
      # no-ops via the marker check above. Uses --no-audit/--no-fund for
      # deterministic, non-interactive activation.
      npm install --prefix "$target_dir" --no-audit --no-fund
    fi
    node "$target_dir/patch-synchronized-ref.cjs" "$target_dir"
    # Patch above is idempotent (sentinel + marker) and fails activation
    # loudly on unexpected bundle shape so the workaround gets revisited
    # instead of silently exporting zero spans.
  '';

  programs.opencode.settings.plugins = [ pluginPath ];
}

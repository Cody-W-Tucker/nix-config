# TEMPORARY workaround for upstream Langfuse plugin bug:
# https://github.com/langfuse/opencode-observability-plugin/issues/55
#
# `@langfuse/opencode-observability-plugin@0.5.2` resolves
# `@opentelemetry/api@1.9.1` while transitive `sdk-logs@3.0.0` requires
# `>=1.10.0`, so the bare npm spec fails at runtime. No fixed upstream
# release exists yet.
#
# REMOVAL CONDITION: delete this directory, drop the `./tools/langfuse`
# import, and restore the bare
# `@langfuse/opencode-observability-plugin@<fixed-version>` spec in
# `users/cody/harness/opencode/default.nix` once the upstream issue is
# closed with a fixed release that pins `@opentelemetry/api >=1.10.0`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Checked-in wrapper (./plugin/package.json + ./plugin/index.ts) that
  # depends on the exact upstream 0.5.2 tarball but overrides
  # @opentelemetry/api to ^1.10.0, plus ./plugin/patch-tracer.cjs which
  # defers the bundled trace.getTracer() call until after
  # NodeTracerProvider.register() (upstream acquires the tracer first, so
  # it binds to the Noop provider and exports zero spans). index.ts is the OpenCode V2 entrypoint
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
    # already matches this wrapper (exact package.json + index.ts and
    # already-patched @opentelemetry/api >= 1.10.0 present).
    need_install=1
    if [ -f "$target_dir/package.json" ] && cmp -s "$wrapper_src/package.json" "$target_dir/package.json" \
      && [ -f "$target_dir/index.ts" ] && cmp -s "$wrapper_src/index.ts" "$target_dir/index.ts" \
      && [ -f "$target_dir/patch-tracer.cjs" ] && cmp -s "$wrapper_src/patch-tracer.cjs" "$target_dir/patch-tracer.cjs"; then
      if [ -f "$target_dir/node_modules/@opentelemetry/api/package.json" ]; then
        api_version="$(node -p "require('$target_dir/node_modules/@opentelemetry/api/package.json').version" 2>/dev/null || echo "")"
        case "$api_version" in
          1.1[0-9]*|1.[2-9][0-9]*|[2-9]*)
            need_install=0
            ;;
        esac
      fi
    fi

    if [ "$need_install" -eq 0 ]; then
      echo "opencode langfuse plugin: already materialized (@opentelemetry/api $api_version), skipping npm install." >&2
    else
      rm -rf "$target_dir"
      mkdir -p "$target_dir"
      cp "$wrapper_src/package.json" "$wrapper_src/index.ts" "$wrapper_src/patch-tracer.cjs" "$target_dir/"
      chmod u+w "$target_dir/package.json" "$target_dir/index.ts" "$target_dir/patch-tracer.cjs"
      # One network install per wrapper change; subsequent activations are
      # no-ops via the marker check above. Uses --no-audit/--no-fund for
      # deterministic, non-interactive activation.
      npm install --prefix "$target_dir" --no-audit --no-fund
    fi
    node "$target_dir/patch-tracer.cjs" "$target_dir"
    # Patch above is idempotent (sentinel + marker) and fails activation
    # loudly on unexpected bundle shape so the workaround gets revisited
    # instead of silently exporting zero spans.
  '';

  programs.opencode.settings.plugins = [ pluginPath ];
}

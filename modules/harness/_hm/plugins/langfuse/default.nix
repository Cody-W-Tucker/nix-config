{
  config,
  lib,
  pkgs,
  ...
}:

let
  wrapperSrc = ./opencode-plugin;

  pluginPath = "${config.xdg.configHome}/opencode/plugins/langfuse-observability";

  nodePkg = pkgs.nodejs;

  claudePlugin = pkgs.callPackage ./claude-package.nix { inherit (pkgs.unstable) python3; };
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

  codyos.workarounds = {
    langfuse-opencode-bun = {
      reason = "OpenCode's Bun runtime fails to initialize SynchronizedRef in the Langfuse OpenCode plugin 0.6.0, so activation patches the bundle. README.md beside this file has the removal test; 0.7.0 is released but untested.";
      upstream = "https://github.com/langfuse/opencode-observability-plugin/issues/55";
      reviewBy = "2026-12-15";
    };
    langfuse-claude-uv-build = {
      reason = "Langfuse 4.15.2 caps uv_build below 0.12 while nixpkgs has 0.12.x, so claude-package.nix relaxes the bound. Its --replace-fail breaks the build once a newer Langfuse drops the cap.";
      upstream = "https://github.com/langfuse/langfuse-python/blob/main/pyproject.toml";
      reviewBy = "2027-01-15";
    };
  };

  codyos.harness.plugins.langfuse-observability = {
    opencode.settings = pluginPath;
    claudeCode.plugin = claudePlugin;
  };

  programs.claude-code.settings.env.CC_LANGFUSE_CAPTURE_IMAGES = "false";
}

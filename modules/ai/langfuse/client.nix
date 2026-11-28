{ den, ... }:
{
  den.aspects.harness.includes = [ den.aspects.langfuse.client ];

  den.aspects.langfuse.client.homeManager =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      wrapperSrc = ./opencode-plugin;
      pluginPath = "${config.xdg.configHome}/opencode/plugins/langfuse-observability";
      piPluginDir = "${config.home.homeDirectory}/.pi/agent/langfuse-plugin";
    in
    {
      sops = {
        secrets."opencode-langfuse-env".mode = "0400";
        templates."opencode-langfuse-env" = {
          mode = "0400";
          content = ''
            ${config.sops.placeholder."opencode-langfuse-env"}
            LANGFUSE_BASE_URL=https://langfuse.${osConfig.codyos.site.domain}
          '';
        };
      };

      programs = {
        opencode.settings.plugins = [ pluginPath ];
        claude-code.settings.env.CC_LANGFUSE_CAPTURE_IMAGES = "false";
      };

      home = {
        file.".pi/agent/extensions/langfuse.ts".text = ''
          export { default } from "${piPluginDir}/node_modules/@langfuse/pi-observability-plugin/src/index.ts";
        '';

        activation.piLangfusePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          PATH="${lib.getBin pkgs.nodejs}/bin:$PATH"
          plugin_dir="${piPluginDir}"
          manifest="$plugin_dir/node_modules/@langfuse/pi-observability-plugin/package.json"
          version="$(node -p "require('$manifest').version" 2>/dev/null || true)"
          if [ "$version" != "0.1.2" ]; then
            mkdir -p "$plugin_dir"
            npm install --prefix "$plugin_dir" --no-save --no-package-lock --ignore-scripts --no-audit --no-fund '@langfuse/pi-observability-plugin@0.1.2'
          fi
        '';

        activation.opencodeLangfusePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          plugin_dir="${config.xdg.configHome}/opencode/plugins"
          target_dir="${pluginPath}"
          wrapper_src="${wrapperSrc}"
          PATH="${lib.getBin pkgs.nodejs}/bin:$PATH"

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
            npm install --prefix "$target_dir" --no-audit --no-fund
          fi
          # The patch is idempotent and fails activation loudly on an unexpected bundle
          # shape, so the workaround gets revisited instead of silently exporting zero spans.
          node "$target_dir/patch-synchronized-ref.cjs" "$target_dir"
        '';

      };

      codyos = {
        harness = {
          agentEnvFiles = [ config.sops.templates."opencode-langfuse-env".path ];
          claudePlugins.langfuse-observability = pkgs.callPackage ./_claude-package.nix {
            inherit (pkgs.unstable) python3;
          };
        };

        workarounds = {
          langfuse-opencode-bun = {
            reason = "OpenCode's Bun runtime fails to initialize SynchronizedRef in the Langfuse OpenCode plugin 0.6.0, so activation patches the bundle. opencode-plugin/README.md has the removal test; 0.7.0 is released but untested.";
            upstream = "https://github.com/langfuse/opencode-observability-plugin/issues/55";
            reviewBy = "2026-12-15";
          };
          langfuse-claude-uv-build = {
            reason = "Langfuse 4.15.2 caps uv_build below 0.12 while nixpkgs has 0.12.x, so _claude-package.nix relaxes the bound. Its --replace-fail breaks the build once a newer Langfuse drops the cap.";
            upstream = "https://github.com/langfuse/langfuse-python/blob/main/pyproject.toml";
            reviewBy = "2027-01-15";
          };
        };
      };
    };
}

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
        opencode.settings.plugins = [ "@langfuse/opencode-observability-plugin@0.7.0" ];
        pi-coding-agent = {
          settings.packages = [ "npm:@langfuse/pi-observability-plugin@0.1.2" ];
          extraPackages = [ pkgs.nodejs ];
        };
        claude-code.settings.env.CC_LANGFUSE_CAPTURE_IMAGES = "false";
      };

      codyos.harness = {
        agentEnvFiles = [ config.sops.templates."opencode-langfuse-env".path ];
        claudePlugins.langfuse-observability = pkgs.callPackage ./_claude-package.nix {
          inherit (pkgs.unstable) python3;
        };
      };

      home.activation.removeMaterializedLangfusePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        rm -rf "${config.xdg.configHome}/opencode/plugins/langfuse-observability" \
          "${config.home.homeDirectory}/.pi/agent/langfuse-plugin"
      '';

      codyos.workarounds = {
        langfuse-materialized-plugins = {
          reason = "OpenCode auto-loads every directory under ~/.config/opencode/plugins, so the old activation-installed Langfuse plugin would trace each turn twice next to the npm one. Drop removeMaterializedLangfusePlugins once beast and the NAS have activated it.";
          upstream = "https://opencode.ai/docs/plugins/";
          reviewBy = "2026-12-31";
        };
        langfuse-claude-uv-build = {
          reason = "Langfuse 4.15.2 caps uv_build below 0.12 while nixpkgs has 0.12.x, so _claude-package.nix relaxes the bound. Its --replace-fail breaks the build once a newer Langfuse drops the cap.";
          upstream = "https://github.com/langfuse/langfuse-python/blob/main/pyproject.toml";
          reviewBy = "2027-01-15";
        };
      };
    };
}

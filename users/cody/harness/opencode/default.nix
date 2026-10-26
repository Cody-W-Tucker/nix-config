{
  lib,
  pkgs,
  config,
  options,
  ...
}:
{
  imports = [
    ./agents/logging
    ./agents/knowledge
    ./skills/humanizer
    ./skills/cognitive
    ./tools/langfuse
    ./tools/rtk
  ];

  # OpenCode Langfuse observability credentials (shared Home Manager scope):
  # the nixos-secrets `opencode-langfuse-env` secret is rendered by a SOPS
  # template (codyt-owned, 0400) plus a declarative LANGFUSE_BASE_URL. Values
  # stay out of the Nix store and out of eval-time substitution.
  sops.secrets."opencode-langfuse-env" = {
    mode = "0400";
  };

  sops.templates."opencode-langfuse-env" = {
    mode = "0400";
    content = ''
      ${config.sops.placeholder."opencode-langfuse-env"}
      LANGFUSE_BASE_URL=https://langfuse.homehub.tv
    '';
  };

  # Langfuse env for interactive OpenCode sessions: source the SOPS-rendered
  # template (set -a exports the payload keys) so OpenCode and related tooling
  # inherit the vars from any interactive zsh.
  programs.zsh.initContent = ''
    # Langfuse credentials for OpenCode and related tooling.
    if [ -f "${config.sops.templates."opencode-langfuse-env".path}" ]; then
      set -a
      . "${config.sops.templates."opencode-langfuse-env".path}"
      set +a
    fi
  '';

  # Langfuse env for the opencode-web user service: systemd services don't run
  # interactive shells, so the zsh sourcing above doesn't cover it; merge the
  # SOPS template as an EnvironmentFile (listOf merges by concatenation with
  # modules/services/opencode/web-service.nix). Harmless where the service is
  # not enabled.
  systemd.user.services.opencode-web.Service.EnvironmentFile = [
    config.sops.templates."opencode-langfuse-env".path
  ];

  # Remove the previously unmanaged legacy plugin so global discovery cannot
  # continue loading it after this configuration is activated.
  home.activation.removeOpenCodeVoicePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "${config.xdg.configHome}/opencode/plugins/voice.ts"
  '';

  # Remove the retired model-router directory plugin and the retired Herdr
  # agent-state plugin so OpenCode plugin discovery cannot keep loading
  # them from previous activations after their Nix modules were removed.
  home.activation.removeRetiredOpenCodePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "${config.xdg.configHome}/opencode/plugins/model-router"
    rm -f "${config.xdg.configHome}/opencode/plugins/model-router.ts"
    rm -f "${config.xdg.configHome}/opencode/plugins/herdr-agent-state.js"
  '';

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    context = ''

      # Environment

      Unless otherwise stated, you are operating in a NixOS system.

      This is a minimal environment. Do not assume system-wide installations of languages or external tools.

      If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
      Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

      Examples:
      - Python: nix shell nixpkgs#python3 --command python script.py
      - Node: nix shell nixpkgs#nodejs --command node script.js
    '';
    settings = {
      # The langfuse module contributes its own entry to this list.
      # Langfuse loads from a managed local plugin path
      # (./tools/langfuse) instead of the bare npm spec as a TEMPORARY
      # workaround for https://github.com/langfuse/opencode-observability-plugin/issues/55
      # (upstream 0.5.2 resolves @opentelemetry/api@1.9.1, sdk-logs@3.0.0
      # needs >=1.10.0). Removal: restore the bare spec once upstream ships
      # a fixed release.
      plugins = [ ];
      autoupdate = false;
      small_model = "opencode-go/deepseek-v4-flash";
      formatter = true;
      default_agent = "build";
      permission.external_directory = {
        "/nix/store" = "allow";
        "/nix/store/**" = "allow";
      };
      lsp = {
        nix = {
          command = [ "${lib.getExe pkgs.nil}" ];
          extensions = [ ".nix" ];
          # 'initialization' passes options directly to the LSP during startup
          initialization = {
            formatting = {
              command = [ "${lib.getExe pkgs.nixfmt}" ];
            };
          };
        };
      };
    };
  }
  // lib.optionalAttrs (options.programs.opencode ? cli) {
    # Stylix still sets the legacy `tui` option. OpenCode 2 reads terminal
    # preferences from cli.json instead.
    tui = lib.mkForce { };
    cli.theme = {
      name = "stylix";
      mode = "system";
    };
  };
}

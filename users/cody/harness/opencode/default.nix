{
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    ./agents/logging
    ./agents/knowledge
    ./skills/humanizer
    ./skills/cognitive
    ./tools/model-router
    ./tools/rtk
  ];

  # OpenCode Langfuse observability credentials (shared Home Manager scope):
  # the nixos-secrets `opencode-langfuse-env` secret is rendered by a SOPS
  # template (codyt-owned, 0400) plus a declarative LANGFUSE_BASEURL. Values
  # stay out of the Nix store and out of eval-time substitution.
  sops.secrets."opencode-langfuse-env" = {
    mode = "0400";
  };

  sops.templates."opencode-langfuse-env" = {
    mode = "0400";
    content = ''
      ${config.sops.placeholder."opencode-langfuse-env"}
      LANGFUSE_BASEURL=https://langfuse.homehub.tv
    '';
  };

  # Langfuse env for interactive OpenCode sessions: source the SOPS-rendered
  # template (set -a exports the payload keys) so OpenCode (and its Langfuse
  # observability plugin) inherits the vars from any interactive zsh.
  programs.zsh.initContent = ''
    # Langfuse credentials for OpenCode (@langfuse/opencode-observability-plugin)
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

  # The 99 nixvim integration brings its own OpenCode-backed model routing,
  # so the model-router plugin file is dropped when 99 is enabled.
  xdg.configFile."opencode/plugins/model-router.ts".enable = lib.mkIf config.cody.editor."99".enable (
    lib.mkForce false
  );

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
      autoupdate = false;
      experimental.openTelemetry = true;
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
      # Langfuse observability plugin (@langfuse/…), configured via the
      # LANGFUSE_PUBLIC_KEY / LANGFUSE_SECRET_KEY / LANGFUSE_BASEURL env vars.
      plugin = [ "@langfuse/opencode-observability-plugin@latest" ];
    };
  };
}

{
  osConfig,
  lib,
  pkgs,
  inputs,
  config,
  options,
  ...
}:
let
  inherit (osConfig.codyos.site) domain;
  opencode = pkgs.unstable.opencode;
in
{
  sops.secrets."opencode-langfuse-env" = {
    mode = "0400";
  };

  sops.templates."opencode-langfuse-env" = {
    mode = "0400";
    content = ''
      ${config.sops.placeholder."opencode-langfuse-env"}
      LANGFUSE_BASE_URL=https://langfuse.${domain}
    '';
  };

  programs.zsh.initContent = ''
    # Langfuse credentials for OpenCode and related tooling.
    if [ -f "${config.sops.templates."opencode-langfuse-env".path}" ]; then
      set -a
      . "${config.sops.templates."opencode-langfuse-env".path}"
      set +a
    fi
  '';

  systemd.user.services.opencode-web.Service.EnvironmentFile = [
    config.sops.templates."opencode-langfuse-env".path
  ];

  home.activation.removeOpenCodeVoicePlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "${config.xdg.configHome}/opencode/plugins/voice.ts"
  '';

  home.activation.removeRetiredOpenCodePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "${config.xdg.configHome}/opencode/plugins/model-router"
    rm -f "${config.xdg.configHome}/opencode/plugins/model-router.ts"
    rm -f "${config.xdg.configHome}/opencode/plugins/herdr-agent-state.js"
  '';

  programs.zsh.shellAliases.op = "opencode";

  programs.opencode = {
    enable = true;
    package = lib.mkDefault opencode;
    enableMcpIntegration = true;
    settings = {
      shell = import ../runtime.nix { inherit inputs lib pkgs; };
      plugins = [
        {
          package = "${
            inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.deja-vu.src
          }/extensions/opencode";
          options = {
            autoRecall = false;
            tools = false;
          };
        }
      ];
      autoupdate = false;
      small_model = "opencode-go/deepseek-v4-flash";
      agents = {
        explore.model = "openai/gpt-6-luna";
        general.model = "openai/gpt-6-luna";
      };
      formatter = true;
      default_agent = "build";
      permission.external_directory = {
        "/nix/store" = "allow";
        "/nix/store/**" = "allow";
      };
      lsp = {
        nix = {
          command = [
            "${lib.getExe pkgs.nixd}"
            "--config=${builtins.toJSON { formatting.command = [ (lib.getExe pkgs.nixfmt) ]; }}"
          ];
          extensions = [ ".nix" ];
        };
      };
    };
  }
  // lib.optionalAttrs (options.programs.opencode ? mutableSettings) {
    mutableSettings = true;
  }
  // lib.optionalAttrs (options.programs.opencode ? cli) {
    tui = lib.mkForce { };
    cli.theme = {
      name = "stylix";
      mode = "system";
    };
  };
}

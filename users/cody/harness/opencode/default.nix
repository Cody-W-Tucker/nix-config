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

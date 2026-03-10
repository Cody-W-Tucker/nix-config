{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./commands/taskwarrior
    ./commands/deslopify
    ./tools/code-search
    ./tools/rtk
    ./skills/obsidian
    ./skills/qmd
  ];

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    settings = {
      theme = lib.mkForce "system";
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
      provider = {
        llama-swap = {
          npm = "@ai-sdk/openai-compatible";
          name = "llama-swap (aiserver)";
          options.baseURL = "http://aiserver:8080/v1";
          models = {
            "qwen3.5-35b" = {
              name = "Qwen3.5";
            };
          };
        };
      };
    };
  };
}

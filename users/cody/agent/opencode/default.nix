{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./scripts
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
        lmstudio = {
          npm = "@ai-sdk/openai-compatible";
          name = "LM Studio (local)";
          options.baseURL = "http://aiserver:1234/v1";
          models = {
            "qwen/qwen3.5-35b-a3b" = {
              name = "Qwen3.5";
            };
          };
        };
      };
    };
  };
}

{
  lib,
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

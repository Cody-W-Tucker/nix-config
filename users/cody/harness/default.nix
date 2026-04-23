{
  config,
  inputs,
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in

{
  imports = [
    inputs.rlm.homeManagerModules.default
    ./opencode
    ./mcp.nix
  ];

  home.packages = [
    llmPkgs.rtk
    llmPkgs.openspec
    llmPkgs.qmd
  ];

  sops.secrets."opencode-zen-api-key" = { };

  programs.rlm = {
    enable = true;
    apiKeyFile = config.sops.secrets."opencode-zen-api-key".path;
    model = "kimi-k2.5";
    openaiBaseUrl = "https://opencode.ai/zen/v1";
  };
}

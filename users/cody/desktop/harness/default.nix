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

  sops.secrets."opencode-api-key" = { };

  programs.rlm = {
    enable = true;
    apiKeyFile = config.sops.secrets."opencode-api-key".path;
    model = "kimi-k2.6";
    subModel = "kimi-k2.6";
    openaiBaseUrl = "https://opencode.ai/zen/go/v1";
  };
}

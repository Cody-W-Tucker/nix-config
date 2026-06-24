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
    ./herdr
    ./mcp.nix
  ];

  home.packages = [
    llmPkgs.openspec
    llmPkgs.qmd
    llmPkgs.grok
  ];

  sops.secrets."opencode-api-key" = { };

  programs.rlm = {
    enable = true;
    apiKeyFile = config.sops.secrets."opencode-api-key".path;
    model = "gpt-5.5";
    subModel = "kimi-k2.6";
    openaiBaseUrl = "https://opencode.ai/zen/v1";
  };
}

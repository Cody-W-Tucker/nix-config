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
    llmPkgs.openspec
    llmPkgs.qmd
    llmPkgs.grok
    llmPkgs.gnhf
    llmPkgs.pi
  ];

  sops.secrets."opencode-api-key" = { };

  programs.rlm = {
    enable = true;
    apiKeyFile = config.sops.secrets."opencode-api-key".path;
    model = "deepseek-v4-pro";
    subModel = "deepseek-v4-flash";
    openaiBaseUrl = "https://opencode.ai/zen/go/v1";
  };
}

{
  inputs,
  osConfig ? { },
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  systemNixpkgsConfig = osConfig.nixpkgs.config or { };
  useRocm = systemNixpkgsConfig.rocmSupport or pkgs.config.rocmSupport or false;
  useCuda = !useRocm && (systemNixpkgsConfig.cudaSupport or pkgs.config.cudaSupport or false);
  qmdPackage = if useCuda then llmPkgs.qmd.override { cudaSupport = true; } else llmPkgs.qmd;
in

{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = [
    qmdPackage
    llmPkgs.coderabbit-cli
    llmPkgs.rtk
    llmPkgs.openspec
    llmPkgs.ck
    inputs.roborev.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}

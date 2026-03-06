{
  inputs,
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  # Only enable CUDA if ROCm (AMD) is not enabled
  useCuda = !(pkgs.config.rocmSupport or false);
in

{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = [
    (if useCuda then llmPkgs.qmd.override { cudaSupport = true; } else llmPkgs.qmd)
    llmPkgs.coderabbit-cli
    llmPkgs.rtk
    llmPkgs.openspec
    llmPkgs.ck
    inputs.roborev.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}

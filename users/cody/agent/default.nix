{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in

{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = [
    # Default is Vulkan, which should work with ROCm natively. CUDA is enabled via override when available.
    (llmPkgs.qmd.override (
      lib.optionalAttrs (pkgs.config.cudaSupport or false) { cudaSupport = true; }
    ))
    llmPkgs.coderabbit-cli
    llmPkgs.rtk
    llmPkgs.openspec
    llmPkgs.ck
    llmPkgs.pi
  ];
}

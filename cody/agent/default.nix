{
  inputs,
  lib,
  osConfig ? { },
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  systemNixpkgsConfig = osConfig.nixpkgs.config or { };
  useRocm = systemNixpkgsConfig.rocmSupport or pkgs.config.rocmSupport or false;
  useCuda = !useRocm && (systemNixpkgsConfig.cudaSupport or pkgs.config.cudaSupport or false);
  qmdPackage = llmPkgs.qmd.override { cudaSupport = useCuda; };
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
  ];

  home.sessionVariables = lib.optionalAttrs useRocm {
    NODE_LLAMA_CPP_GPU = "vulkan";
  };
}

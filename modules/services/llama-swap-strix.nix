# llama-swap with Strix Halo (gfx1151) optimized llama.cpp
# ROCm/HIP optimized wrapper for NixOS llama-swap module

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-swap-strix;

  # Strix-optimized llama-cpp with gfx1151 support
  llama-cpp-strix = pkgs.callPackage ../../packages/llama-cpp-strix.nix { };
in
{
  options.services.llama-swap-strix = {
    enable = lib.mkEnableOption "llama-swap with ROCm-optimized llama.cpp for Strix Halo";
  };

  config = lib.mkIf cfg.enable {
    # Enable upstream llama-swap module
    services.llama-swap.enable = true;

    # Provide ROCm-optimized llama-server via environment
    # Users can reference it in their settings as: ${pkgs.llama-cpp-strix}/bin/llama-server
    # or use the Strix-optimized package directly in their config
    environment.systemPackages = [ llama-cpp-strix ];

    # ROCm/HIP environment for GPU acceleration
    systemd.services.llama-swap.environment = {
      HSA_OVERRIDE_GFX_VERSION = "11.5.1";
      ROCM_PATH = "${pkgs.rocmPackages.rocm-core}";
      HIP_PATH = "${pkgs.rocmPackages.rocm-core}";
    };

    # Disable the direct llama-cpp service to avoid conflicts
    services.llama-cpp.enable = lib.mkForce false;
  };
}

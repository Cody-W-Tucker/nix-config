{ inputs, ... }:

{
  imports = [
    # Host files
    ./ai.nix
    ./drives.nix
    ./machine.nix
    ./models.nix

    # Shared modules
    ../../modules/system/base.nix
    ../../modules/desktop
    ../../modules/desktop/gaming
    ../../modules/desktop/hardware/nvidia.nix
    ../../modules/services/llama-swap
    ../../modules/services/hermes-agent

    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];
}

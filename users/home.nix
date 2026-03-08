{
  config,
  lib,
  inputs,
  pkgs-unstable ? null,
  ...
}:

{
  home-manager = {
    # Note: extraSpecialArgs and hardwareConfig should be set per-host
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";

    sharedModules = [
      inputs.sops-nix.homeModules.sops
      inputs.stylix.homeModules.stylix
    ];
  };
}

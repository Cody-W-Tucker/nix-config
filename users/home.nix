{
  config,
  lib,
  inputs,
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

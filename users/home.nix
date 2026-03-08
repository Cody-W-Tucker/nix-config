{
  config,
  lib,
  inputs,
  pkgs-unstable ? null,
  ...
}:

{
  nixpkgs.config.allowUnfreePredicate = lib.mkDefault (_: true);

  home-manager = {
    # Note: extraSpecialArgs and hardwareConfig should be set per-host
    useGlobalPkgs = false;
    useUserPackages = true;
    backupFileExtension = "backup";

    sharedModules = [
      inputs.sops-nix.homeModules.sops
      inputs.stylix.homeModules.stylix
    ];
  };
}

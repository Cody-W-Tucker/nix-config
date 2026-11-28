{
  den,
  inputs,
  lib,
  ...
}:
{
  den = {
    aspects.home-manager.nixos.home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      sharedModules = [ inputs.sops-nix.homeModules.sops ];
      extraSpecialArgs = { inherit inputs; };
    };

    default.includes = [ den.aspects.home-manager ];
    migrations.user-host-content.acknowledged = true;
    schema.user.classes = lib.mkDefault [
      "user"
      "homeManager"
    ];
  };
}

{
  den,
  inputs,
  lib,
  ...
}:
{
  den.aspects.home-manager.nixos = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";

      sharedModules = [
        inputs.sops-nix.homeModules.sops
      ];

      extraSpecialArgs = {
        inherit inputs;
      };
    };
  };

  den.default.includes = [ den.aspects.home-manager ];

  den.migrations.user-host-content.acknowledged = true;

  den.schema.user.classes = lib.mkDefault [
    "user"
    "homeManager"
  ];
}

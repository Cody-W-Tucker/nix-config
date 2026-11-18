{
  den,
  inputs,
  lib,
  ...
}:
{
  # Home Manager integration. Den's home-manager battery imports the per-host
  # `host.home-manager.module` (set in modules/hosts/<host>.nix) and forwards every
  # user's `homeManager` class into home-manager.users.<name>. Den sets none of the
  # options below, so they live here.
  den.aspects.home-manager.nixos = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";

      sharedModules = [
        inputs.sops-nix.homeModules.sops
      ];

      # Arguments every Home Manager module may take (also during `imports`).
      extraSpecialArgs = {
        inherit inputs;
      };
    };
  };

  den.aspects.base.includes = [ den.aspects.home-manager ];

  # User aspects carry only user-scope content (homeManager, user); anything for the
  # host belongs to a host aspect. Adopt that Den 0.20 behaviour before 2027-01-01.
  den.migrations.user-host-content.acknowledged = true;

  # Every user gets a Home Manager environment and a users.users entry.
  den.schema.user.classes = lib.mkDefault [
    "user"
    "homeManager"
  ];
}

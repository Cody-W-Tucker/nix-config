{ den, inputs, ... }:
{
  den.aspects.nas = {
    includes = [
      den.aspects.base
      den.aspects.nas-role
      den.aspects.hermes-agent
      den.aspects.hindsight
      den.aspects.opencode
    ];

    nixos =
      { config, ... }:
      {
        imports = [
          # Stable Home Manager pairs with stable nixpkgs.
          inputs.home-manager-stable.nixosModules.home-manager
          ../../hosts/nas
        ];

        home-manager = {
          extraSpecialArgs = {
            inherit inputs;
          };
          users.${config.codyos.site.user.name} = {
            home.stateVersion = "25.11";
            imports = [
              ../../users/cody/server.nix
              # Hermes HM module tree; its NixOS backup wiring is den.aspects.hermes-agent.
              ../../modules/services/hermes-agent
              inputs.nixos-secrets.homeModules.default
              # Stable nixvim pairs with stable Home Manager.
              inputs.nixvim-stable.homeModules.nixvim
            ];
          };
        };
      };
  };
}

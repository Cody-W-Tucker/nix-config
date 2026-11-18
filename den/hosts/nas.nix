{ den, inputs, ... }:
{
  den.aspects.nas = {
    includes = [
      den.aspects.base
      den.aspects.nas-role
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
              ../../modules/services/hermes-agent
              inputs.nixos-secrets.homeModules.default
              inputs.nixvim-stable.homeModules.nixvim
            ];
          };
        };
      };
  };
}

{ inputs, ... }:
let
  mkInstantiate = import ./_instantiate.nix { inherit inputs; };

  # Each channel pairs a nixpkgs with the Home Manager and NixVim releases built for it.
  # The HM-version checks in modules/harness/_hm/ rely on this pairing.
  channels = {
    stable = {
      inherit (inputs) nixpkgs;
      home-manager = inputs.home-manager-stable;
      nixvim = inputs.nixvim-stable;
    };
    # `home-manager` is HM master following nixpkgs-unstable.
    unstable = {
      nixpkgs = inputs.nixpkgs-unstable;
      inherit (inputs) home-manager nixvim;
    };
  };
in
{
  # A host says only `channel = "stable" | "unstable"`; its builder, Home Manager module and
  # NixVim module follow from it (mkDefault, so one host can still override any of them).
  den.schema.host =
    { config, lib, ... }:
    let
      channel = channels.${config.channel};
    in
    {
      options = {
        channel = lib.mkOption {
          type = lib.types.enum (builtins.attrNames channels);
          description = "nixpkgs channel the host is built from (selects the paired HM and NixVim).";
        };
        nixvimModule = lib.mkOption {
          type = lib.types.raw;
          description = "NixVim Home Manager module matching the host's channel.";
        };
      };

      config = {
        instantiate = lib.mkDefault (mkInstantiate {
          inherit (channel.nixpkgs.lib) nixosSystem;
          inherit (config) system;
        });
        home-manager.module = lib.mkDefault channel.home-manager.nixosModules.home-manager;
        nixvimModule = lib.mkDefault channel.nixvim.homeModules.nixvim;
      };
    };
}

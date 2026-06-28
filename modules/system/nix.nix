# Nix package manager settings

{ config, ... }:

{
  nixpkgs.config.allowUnfree = true;

  sops.secrets."github-nix-secrets-read" = { };
  sops.templates."nix-access-tokens.conf" = {
    content = ''
      access-tokens = github.com=${config.sops.placeholder."github-nix-secrets-read"}
    '';
    owner = "root";
    group = "wheel";
    mode = "0440";
  };

  nix = {
    extraOptions = ''
      !include ${config.sops.templates."nix-access-tokens.conf".path}
    '';
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [
        "https://cache.numtide.com"
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}

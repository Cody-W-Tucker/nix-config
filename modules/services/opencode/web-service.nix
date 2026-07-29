{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

let
  cfg = config.services.opencode;
in
{
  config = lib.mkIf cfg.enable {
    home-manager.users.codyt = {
      programs.opencode = {
        enable = true;
        package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.opencode;
        web.enable = true;
        web.environmentFile = config.sops.templates."opencode-env".path;
        web.extraArgs = [
          "--hostname"
          "127.0.0.1"
          "--port"
          "4096"
        ];
      };
    };
  };
}

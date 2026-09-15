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
        web.extraArgs = [
          "--hostname"
          "127.0.0.1"
          "--port"
          "4096"
        ];
      };

      # EnvironmentFiles for the user-level opencode-web service:
      #   - opencode-env SOPS template (OPENCODE_SERVER_PASSWORD)
      #   - Langfuse plugin credentials rendered by opencode-langfuse-env
      #     (hosts/nas/models.nix) from the `opencode-langfuse-env` SOPS
      #     secret; codyt-owned 0400.
      systemd.user.services.opencode-web.Service.EnvironmentFile = [
        config.sops.templates."opencode-env".path
        "/run/opencode-langfuse/opencode-langfuse-env"
      ];
    };
  };
}

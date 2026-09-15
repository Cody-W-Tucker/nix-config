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
      #   - opencode-langfuse-env SOPS template: the `opencode-langfuse-env`
      #     secret payload (hosts/nas/models.nix) plus LANGFUSE_BASEURL;
      #     codyt-owned 0400.
      systemd.user.services.opencode-web.Service.EnvironmentFile = [
        config.sops.templates."opencode-env".path
        config.sops.templates."opencode-langfuse-env".path
      ];
    };
  };
}

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

      # EnvironmentFile for the user-level opencode-web service:
      #   - opencode-env SOPS template (OPENCODE_SERVER_PASSWORD)
      # The Langfuse env file is merged in by the shared Home Manager harness
      # (users/cody/harness/opencode/default.nix), which owns the
      # opencode-langfuse-env SOPS template.
      systemd.user.services.opencode-web.Service.EnvironmentFile = [
        config.sops.templates."opencode-env".path
      ];
    };
  };
}

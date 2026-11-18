{
  config,
  lib,
  mkNginxVhost,
  ...
}:

let
  inherit (config.codyos.site) domain;
  cfg = config.codyos.opencode;
in
{
  options.codyos.opencode = {
    enable = lib.mkEnableOption "OpenCode web service";
  };

  config = lib.mkIf cfg.enable {
    # OpenCode password secret
    sops.secrets."opencode-password" = {
      owner = config.codyos.site.user.name;
    };

    # Runtime env file for OpenCode web service (systemd EnvironmentFile format)
    sops.templates."opencode-env" = {
      content = ''
        OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode-password"}
      '';
      owner = config.codyos.site.user.name;
    };

    # Allow codyt's services to linger after logout
    users.users.${config.codyos.site.user.name}.linger = true;

    # OpenCode nginx virtual host
    services.nginx.virtualHosts = mkNginxVhost {
      host = "opencode.${domain}";
      port = 4096;
      proxyWebsockets = true;
    };

    home-manager.users.${config.codyos.site.user.name} = {
      programs.opencode = {
        enable = true;
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

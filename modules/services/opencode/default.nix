{
  config,
  lib,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  cfg = config.services.opencode;
in
{
  imports = [
    ./web-service.nix
  ];

  options.services.opencode = {
    enable = lib.mkEnableOption "OpenCode web service";
  };

  config = lib.mkIf cfg.enable {
    # OpenCode password secret
    sops.secrets."opencode-password" = {
      owner = "codyt";
    };

    # Runtime env file for OpenCode web service (systemd EnvironmentFile format)
    sops.templates."opencode-env" = {
      content = ''
        OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode-password"}
      '';
      owner = "codyt";
    };

    # Allow codyt's services to linger after logout
    users.users.codyt.linger = true;

    # OpenCode nginx virtual host
    services.nginx.virtualHosts = mkNginxVhost {
      host = "opencode.homehub.tv";
      port = 4096;
      proxyWebsockets = true;
      proxyHost = "127.0.0.1";
    };
  };
}

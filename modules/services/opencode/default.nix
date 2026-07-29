{
  config,
  lib,
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
    services.nginx.virtualHosts."opencode.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:4096";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}

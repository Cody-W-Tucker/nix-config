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
  imports = [
    ./web-service.nix
  ];

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
      proxyHost = "127.0.0.1";
    };
  };
}

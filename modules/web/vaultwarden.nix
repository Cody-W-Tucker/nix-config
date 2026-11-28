{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.vaultwarden ];

  den.aspects.vaultwarden.nixos =
    {
      config,
      mkNginxVhost,
      ...
    }:
    let
      inherit (config.codyos.site) domain;
      host = "vault.${domain}";
      port = 8222;
      dataDir = "/var/lib/vaultwarden";
    in
    {
      codyos.homepage.cards.Vaultwarden = {
        group = "Tools";
        order = 80;
        card = {
          href = "https://${host}";
          icon = "vaultwarden";
          description = "Passwords";
        };
      };

      sops.secrets."vaultwarden-admin-token" = { };
      sops.templates."vaultwarden-env".content = ''
        ADMIN_TOKEN=${config.sops.placeholder."vaultwarden-admin-token"}
      '';

      services = {
        vaultwarden = {
          enable = true;
          domain = host;
          environmentFile = config.sops.templates."vaultwarden-env".path;
          config = {
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = port;
            SIGNUPS_ALLOWED = false;
            INVITATIONS_ALLOWED = true;
            SHOW_PASSWORD_HINT = false;
          };
        };

        nginx.virtualHosts = mkNginxVhost {
          inherit host port;
          proxyWebsockets = true;
          locationExtraConfig = ''
            client_max_body_size 525M;
          '';
        };

        fail2ban.jails.vaultwarden = {
          filter.Definition = {
            failregex = builtins.concatStringsSep "\n    " [
              ''^.*Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$''
              ''^.*Invalid admin token\. IP: <ADDR>.*$''
              "^.*Invalid TOTP code! Server time: .* IP: <ADDR>$"
            ];
            ignoreregex = "";
          };
          settings = {
            backend = "systemd";
            journalmatch = "_SYSTEMD_UNIT=vaultwarden.service";
            port = "http,https";
          };
        };

        restic.backups.nas-files.exclude = map (suffix: "${dataDir}/${suffix}") [
          "db.sqlite3"
          "db.sqlite3-wal"
          "db.sqlite3-shm"
          "icon_cache"
          "tmp"
        ];
      };

      nas.backups = {
        sqlite = [
          {
            name = "vaultwarden";
            source = "${dataDir}/db.sqlite3";
            filename = "db.sqlite3";
          }
        ];
        dataDirectories = [ dataDir ];
      };
    };
}

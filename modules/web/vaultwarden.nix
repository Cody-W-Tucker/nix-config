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

      # Argon2 PHC hash of the /admin token, not the token itself.
      sops.secrets."vaultwarden-admin-token" = { };
      sops.templates."vaultwarden-env".content = ''
        ADMIN_TOKEN=${config.sops.placeholder."vaultwarden-admin-token"}
      '';

      services.vaultwarden = {
        enable = true;
        domain = host;
        environmentFile = config.sops.templates."vaultwarden-env".path;
        config = {
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = port;
          # Accounts come from /admin invitations; without SMTP an invited
          # address registers directly in the web vault.
          SIGNUPS_ALLOWED = false;
          INVITATIONS_ALLOWED = true;
          SHOW_PASSWORD_HINT = false;
        };
      };

      services.nginx.virtualHosts = mkNginxVhost {
        inherit host port;
        proxyWebsockets = true;
        # Attachments and Sends upload through the proxy.
        locationExtraConfig = ''
          client_max_body_size 525M;
        '';
      };

      # nginx sets X-Real-IP, so Vaultwarden logs the client address.
      services.fail2ban.jails.vaultwarden = {
        filter.Definition = {
          # Continuation lines must be indented in fail2ban's INI format.
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

      # The vault database is exported consistently before Restic runs; keys,
      # attachments, Sends and admin settings are read live. Icons are refetched.
      nas.backups.sqlite = [
        {
          name = "vaultwarden";
          source = "${dataDir}/db.sqlite3";
          filename = "db.sqlite3";
        }
      ];
      nas.backups.dataDirectories = [ dataDir ];
      services.restic.backups.nas-files.exclude = map (suffix: "${dataDir}/${suffix}") [
        "db.sqlite3"
        "db.sqlite3-wal"
        "db.sqlite3-shm"
        "icon_cache"
        "tmp"
      ];
    };
}

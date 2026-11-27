{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.miniflux ];

  den.aspects.miniflux.nixos =
    {
      mkNginxVhost,
      config,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Miniflux = {
        group = "Consume";
        order = 60;
        card = {
          href = "https://rss.${domain}";
          icon = "miniflux";
          description = "RSS Reader";
        };
      };

      sops = {
        secrets = {
          "miniflux/ADMIN_PASSWORD" = { };
          "miniflux/ADMIN_USERNAME" = { };
          "miniflux/API_KEY" = {
            group = config.users.groups.miniflux-curator.name;
            owner = config.users.users.miniflux-curator.name;
          };
          "karakeep-api-key" = {
            group = "users";
            owner = config.users.users.miniflux-curator.name;
            mode = "0440";
          };
        };

        templates."miniflux-credentials".content = ''
          ADMIN_USERNAME=${config.sops.placeholder."miniflux/ADMIN_USERNAME"}
          ADMIN_PASSWORD=${config.sops.placeholder."miniflux/ADMIN_PASSWORD"}
        '';
      };

      services = {
        miniflux = {
          enable = true;
          config = {
            CLEANUP_FREQUENCY = 48;
            LISTEN_ADDR = "localhost:7777";
            BASE_URL = "https://rss.${domain}";
            INTEGRATION_ALLOW_PRIVATE_NETWORKS = "1";
          };
          adminCredentialsFile = config.sops.templates."miniflux-credentials".path;
        };

        miniflux-curator = {
          minifluxUrl = "http://localhost:7777";
          apiKeyFile = config.sops.secrets."miniflux/API_KEY".path;
          karakeepUrl = "https://karakeep.${domain}";
          karakeepApiKeyFile = config.sops.secrets."karakeep-api-key".path;
          openaiHost = "http://127.0.0.1:8081";
          embedModel = "qwen3-embedding-0.6b";
          autoMarkReadBelow = 4.5;
          limitUnread = 400;
          karakeepFetchLimit = 100;
          referenceLimit = 50;
          batchSize = 64;
          dryRun = false;
          schedule = "*-*-* 07:15,23:15";
        };

        nginx.virtualHosts = mkNginxVhost {
          host = "rss.${domain}";
          port = 7777;
        };
      };
    };
}

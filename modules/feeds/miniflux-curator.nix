{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.miniflux-curator ];

  den.aspects.miniflux-curator.nixos =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:

    let
      inherit (lib) mkOption types;
      cfg = config.services.miniflux-curator;
      curatorScript = inputs.miniflux-curator.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in

    {
      options.services.miniflux-curator = {
        minifluxUrl = mkOption {
          type = types.str;
          default = "http://localhost:7777";
          description = "Miniflux instance URL";
        };

        apiKeyFile = mkOption {
          type = types.path;
          description = "Path to file containing Miniflux API key";
        };

        karakeepUrl = mkOption {
          type = types.str;
          default = "http://localhost:3000";
          description = "Karakeep instance URL";
        };

        karakeepApiKeyFile = mkOption {
          type = types.path;
          description = "Path to file containing Karakeep API key";
        };

        openaiHost = mkOption {
          type = types.str;
          default = "http://localhost:8080";
          description = "Embedding API host (OpenAI-compatible)";
        };

        embedModel = mkOption {
          type = types.str;
          default = "qwen3-embedding-8b";
          description = "Embedding model for similarity scoring";
        };

        batchSize = mkOption {
          type = types.int;
          default = 64;
          description = "Number of articles to embed per batch request (default: 64)";
        };

        karakeepFetchLimit = mkOption {
          type = types.int;
          default = 100;
          description = "Number of recent Karakeep bookmarks to fetch before reference selection";
        };

        referenceLimit = mkOption {
          type = types.int;
          default = 50;
          description = "Maximum Karakeep bookmarks selected for reference embeddings";
        };

        autoMarkReadBelow = mkOption {
          type = types.float;
          default = 3.5;
          description = "Score threshold below which entries are marked as read (0-10)";
        };

        limitUnread = mkOption {
          type = types.int;
          default = 400;
          description = "Maximum unread entries to process per run";
        };

        dryRun = mkOption {
          type = types.bool;
          default = true;
          description = "When true, only logs what would be done without making changes";
        };

        schedule = mkOption {
          type = types.str;
          default = "daily";
          description = "Schedule for running the curator (systemd timer format)";
        };
      };

      config = {
        systemd.services.miniflux-curator = {
          description = "Miniflux RSS Auto-Curator";
          serviceConfig = {
            Type = "oneshot";
            User = "miniflux-curator";
            Group = "miniflux-curator";
            WorkingDirectory = "/var/lib/miniflux-curator";
          };
          path = [ curatorScript ];
          environment = {
            MINIFLUX_URL = cfg.minifluxUrl;
            KARAKEEP_URL = cfg.karakeepUrl;
            OPENAI_HOST = cfg.openaiHost;
            EMBED_MODEL = cfg.embedModel;
            AUTO_MARK_READ_BELOW = toString cfg.autoMarkReadBelow;
            LIMIT_UNREAD = toString cfg.limitUnread;
            DRY_RUN = lib.boolToString cfg.dryRun;
            BATCH_SIZE = toString cfg.batchSize;
            KARAKEEP_FETCH_LIMIT = toString cfg.karakeepFetchLimit;
            REFERENCE_LIMIT = toString cfg.referenceLimit;
            STATE_FILE = "/var/lib/miniflux-curator/state.json";
          };
          script = ''
            export MINIFLUX_API_KEY=$(cat ${cfg.apiKeyFile})
            export KARAKEEP_API_KEY=$(cat ${cfg.karakeepApiKeyFile})
            miniflux-curator
          '';
          startAt = cfg.schedule;
        };
        users.users.miniflux-curator = {
          isSystemUser = true;
          group = "miniflux-curator";
          home = "/var/lib/miniflux-curator";
          createHome = true;
        };
        users.groups.miniflux-curator = { };
        systemd.tmpfiles.rules = [
          "d /var/lib/miniflux-curator 0750 miniflux-curator miniflux-curator -"
        ];
      };
    };
}

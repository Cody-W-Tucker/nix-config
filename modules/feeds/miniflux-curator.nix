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
      options.services.miniflux-curator =
        let
          option =
            type: default: description:
            mkOption { inherit type default description; };
          required = type: description: mkOption { inherit type description; };
        in
        {
          minifluxUrl = option types.str "http://localhost:7777" "Miniflux instance URL";
          apiKeyFile = required types.path "Path to file containing Miniflux API key";
          karakeepUrl = option types.str "http://localhost:3000" "Karakeep instance URL";
          karakeepApiKeyFile = required types.path "Path to file containing Karakeep API key";
          openaiHost = option types.str "http://localhost:8080" "Embedding API host (OpenAI-compatible)";
          embedModel = option types.str "qwen3-embedding-8b" "Embedding model for similarity scoring";
          batchSize = option types.int 64 "Number of articles to embed per batch request (default: 64)";
          karakeepFetchLimit =
            option types.int 100
              "Number of recent Karakeep bookmarks to fetch before reference selection";
          referenceLimit = option types.int 50 "Maximum Karakeep bookmarks selected for reference embeddings";
          autoMarkReadBelow =
            option types.float 3.5
              "Score threshold below which entries are marked as read (0-10)";
          limitUnread = option types.int 400 "Maximum unread entries to process per run";
          dryRun = option types.bool true "When true, only logs what would be done without making changes";
          schedule = option types.str "daily" "Schedule for running the curator (systemd timer format)";
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

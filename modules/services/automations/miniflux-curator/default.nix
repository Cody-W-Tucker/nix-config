{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.miniflux-curator;
  curatorScript = import ./script.nix { inherit pkgs inputs; };
in

{
  options.services.miniflux-curator = {
    enable = lib.mkEnableOption "Miniflux auto-curator service";

    minifluxUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:7777";
      description = "Miniflux instance URL";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing Miniflux API key";
    };

    ollamaHost = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:11434";
      description = "Ollama API host";
    };

    llmModel = lib.mkOption {
      type = lib.types.str;
      default = "llama3.2";
      description = "Ollama LLM model for reasoning";
    };

    embedModel = lib.mkOption {
      type = lib.types.str;
      default = "nomic-embed-text";
      description = "Ollama embedding model";
    };

    autoMarkReadBelow = lib.mkOption {
      type = lib.types.float;
      default = 3.5;
      description = "Score threshold below which entries are marked as read (0-10)";
    };

    limitUnread = lib.mkOption {
      type = lib.types.int;
      default = 400;
      description = "Maximum unread entries to process per run";
    };

    dryRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When true, only logs what would be done without making changes";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Schedule for running the curator (systemd timer format)";
    };
  };

  config = lib.mkIf cfg.enable {
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
        OLLAMA_HOST = cfg.ollamaHost;
        LLM_MODEL = cfg.llmModel;
        EMBED_MODEL = cfg.embedModel;
        AUTO_MARK_READ_BELOW = toString cfg.autoMarkReadBelow;
        LIMIT_UNREAD = toString cfg.limitUnread;
        DRY_RUN = lib.boolToString cfg.dryRun;
      };
      script = ''
        export MINIFLUX_API_KEY=$(cat ${cfg.apiKeyFile})
        miniflux-curator
      '';
      startAt = cfg.schedule;
    };

    # Create dedicated user
    users.users.miniflux-curator = {
      isSystemUser = true;
      group = "miniflux-curator";
      home = "/var/lib/miniflux-curator";
      createHome = true;
    };
    users.groups.miniflux-curator = { };

    # Ensure working directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/miniflux-curator 0750 miniflux-curator miniflux-curator -"
    ];
  };
}

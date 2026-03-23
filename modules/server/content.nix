{ config, pkgs, ... }:

{
  imports = [
    ../services/automations/miniflux-curator
  ];

  sops = {
    secrets."miniflux/ADMIN_USERNAME" = { };
    secrets."miniflux/ADMIN_PASSWORD" = { };
    secrets."miniflux/API_KEY" = {
      owner = config.users.users.miniflux-curator.name;
      group = config.users.groups.miniflux-curator.name;
    };

    templates."miniflux-credentials".content = ''
      ADMIN_USERNAME=${config.sops.placeholder."miniflux/ADMIN_USERNAME"}
      ADMIN_PASSWORD=${config.sops.placeholder."miniflux/ADMIN_PASSWORD"}
    '';
  };

  services = {
    # Miniflux RSS reader
    miniflux = {
      enable = true;
      config = {
        CLEANUP_FREQUENCY = 48;
        LISTEN_ADDR = "localhost:7777";
        BASE_URL = "https://rss.homehub.tv";
        INTEGRATION_ALLOW_PRIVATE_NETWORKS = "1";
      };
      adminCredentialsFile = config.sops.templates."miniflux-credentials".path;
    };

    # Auto-curator for cleaning up low-relevance articles
    miniflux-curator = {
      enable = true;
      minifluxUrl = "http://localhost:7777";
      apiKeyFile = config.sops.secrets."miniflux/API_KEY".path;
      ollamaHost = "http://aiserver:8080";
      llmModel = "gemma-3-12b";
      embedModel = "qwen3-embedding-8b";
      autoMarkReadBelow = 5.0;
      limitUnread = 400;
      maxWorkers = 6;
      dryRun = true; # Start in dry-run mode - set to false after testing
      schedule = "*-*-* 00,04,08,12,16,20:00"; # Every 4 hours
    };

    nginx.virtualHosts."rss.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://localhost:7777";
      };
      kTLS = true;
    };
  };

  # Ensure curator can reach Ollama on beast via the proxy
  networking.hosts."192.168.1.20" = [ "beast" ];
}

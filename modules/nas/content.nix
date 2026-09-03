{
  mkNginxVhost,
  config,
  ...
}:

{
  imports = [
    ../services/automations/miniflux-curator
  ];

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
    # Miniflux RSS reader. Theme: https://github.com/andymason/miniflux-css-theme/tree/main
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
      karakeepUrl = "https://karakeep.homehub.tv";
      karakeepApiKeyFile = config.sops.secrets."karakeep-api-key".path;
      openaiHost = "https://ai.homehub.tv/v1";
      # OPENAI_API_KEY for the LiteLLM gateway, derived at activation from
      # LITELLM_MASTER_KEY inside litellm-env (modules/nas/litellm). No literal
      # key in Nix; root-owned 0400 (see litellm-openai-api-key-env.service).
      openaiApiKeyEnvFile = "/run/litellm-openai-api-key/openai-api-key-env";
      embedModel = "qwen3-embedding-0.6b";
      autoMarkReadBelow = 4.5;
      limitUnread = 400;
      karakeepFetchLimit = 100;
      referenceLimit = 50;
      batchSize = 64;
      dryRun = false; # set true to test
      schedule = "*-*-* 07:15,23:15"; # 7:15am and 11:15pm
    };

    nginx.virtualHosts = mkNginxVhost {
      host = "rss.homehub.tv";
      port = 7777;
    };
  };
}

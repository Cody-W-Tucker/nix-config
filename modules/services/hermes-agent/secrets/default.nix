{ config, ... }:

{
  config.sops = {
    secrets = {
      "opencode-api-key" = { };
      "firecrawl-api-key" = { };
      "hermes-api-server-key" = { };
      "hermes-discord-bot-token" = { };
      "hermes-discord-allowed-users" = { };
      "hermes-telegram-bot-token" = { };
      "hermes-telegram-allowed-users" = { };
    };

    templates."hermes-env" = {
      content = ''
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
        FIRECRAWL_API_KEY=${config.sops.placeholder."firecrawl-api-key"}
        API_SERVER_KEY=${config.sops.placeholder."hermes-api-server-key"}
        DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes-discord-bot-token"}
        DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes-discord-allowed-users"}
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes-telegram-bot-token"}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes-telegram-allowed-users"}
        KARAKEEP_API_KEY=${config.sops.placeholder."karakeep-api-key"}
      '';
    };
  };
}

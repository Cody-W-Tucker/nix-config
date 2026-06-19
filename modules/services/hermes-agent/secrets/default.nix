{ config, ... }:

{
  config.sops = {
    secrets = {
      "opencode-api-key" = { };
      "xai-api-key" = { };
      "firecrawl-api-key" = { };
      "hermes-discord-bot-token" = { };
      "hermes-discord-allowed-users" = { };
      "hermes-telegram-bot-token" = { };
      "hermes-telegram-allowed-users" = { };
    };

    templates."hermes-env" = {
      content = ''
        OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
        XAI_API_KEY=${config.sops.placeholder."xai-api-key"}
        FIRECRAWL_API_KEY=${config.sops.placeholder."firecrawl-api-key"}
        DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes-discord-bot-token"}
        DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes-discord-allowed-users"}
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes-telegram-bot-token"}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes-telegram-allowed-users"}
      '';
    };
  };
}

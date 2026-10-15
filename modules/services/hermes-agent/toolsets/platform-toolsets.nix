let
  primaryToolsets = [
    "web"
    "search"
    "browser"
    "skills"
    "file"
    "memory"
    "session_search"
    "terminal"
    "code_execution"
    "cronjob"
    "clarify"
    "delegation"
    "vision"
    "x_search"
    "a2a"
    "todo"
    "homeassistant"
  ];
  cronToolsets = [
    "web"
    "search"
    "skills"
    "memory"
    "session_search"
    "terminal"
    "homeassistant"
  ];
  webhookToolsets = [
    "web"
    "search"
    "browser"
    "skills"
    "file"
    "memory"
    "session_search"
    "terminal"
    "homeassistant"
  ];
in
{
  config.services.hermes-agent.settings.platform_toolsets = {
    api_server = primaryToolsets;
    telegram = primaryToolsets;
    cli = primaryToolsets;
    discord = primaryToolsets;
    acp = primaryToolsets;
    cron = cronToolsets;
    webhook = webhookToolsets;
  };
}

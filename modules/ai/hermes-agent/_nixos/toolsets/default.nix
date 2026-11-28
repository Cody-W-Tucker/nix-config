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
  services.hermes-agent.settings = {
    web = {
      search_backend = "xai";
      extract_backend = "firecrawl";
      crawl_backend = "firecrawl";
    };
    platform_toolsets = {
      api_server = primaryToolsets;
      telegram = primaryToolsets;
      cli = primaryToolsets;
      discord = primaryToolsets;
      acp = primaryToolsets;
      cron = cronToolsets;
      webhook = webhookToolsets;
    };
  };
}

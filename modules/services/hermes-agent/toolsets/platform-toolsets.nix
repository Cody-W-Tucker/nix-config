let
  apiToolsets = [
    "web"
    "search"
    "vision"
    "skills"
    "cronjob"
    "messaging"
    "file"
    "tts"
    "todo"
    "memory"
    "session_search"
    "clarify"
    "code_execution"
    "delegation"
    "kanban"
    "terminal"
  ];

  # Desktop shares cli toolsets
  cliToolsets = [
    "web"
    "search"
    "vision"
    "skills"
    "cronjob"
    "file"
    "todo"
    "memory"
    "session_search"
    "clarify"
    "code_execution"
    "delegation"
    "kanban"
    "terminal"
  ];

  minimalInteractiveToolsets = [
    "web"
    "search"
    "vision"
    "skills"
    "file"
    "todo"
    "memory"
    "session_search"
  ];

  minimalCronToolsets = [
    "web"
    "search"
    "vision"
    "skills"
    "file"
    "memory"
    "session_search"
  ];
in
{
  config.services.hermes-agent.settings = {
    # Hermes gateway/CLI resolves active tools from platform_toolsets, not the
    # top-level toolsets key. Keep the high-trust interfaces broad and the
    # ambient/background ones narrow.
    platform_toolsets = {
      api_server = apiToolsets;
      cli = cliToolsets;
      telegram = apiToolsets;

      # Discord is noisy and easy to distract through. Keep it oriented toward
      # grounded research, recall, and handoff rather than broad execution
      # surface.
      discord = minimalInteractiveToolsets;

      # Cron should stay narrow: enough to inspect, recall, and run bounded
      # work, but not the whole interactive surface.
      cron = minimalCronToolsets;
    };
  };
}

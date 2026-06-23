let
  apiToolsets = [
    "web"
    "search"
    "skills"
    "cronjob"
    "messaging"
    "file"
    "todo"
    "memory"
    "session_search"
    "terminal"
  ];
in
{
  config.services.hermes-agent.settings = {
    # Hermes gateway/CLI resolves active tools from platform_toolsets, not the top-level toolsets key. Keep the high-trust interfaces broad and the ambient/background ones narrow.
    platform_toolsets = {
      api_server = apiToolsets;
      telegram = apiToolsets;

      # desktop and cli tool under the user that launches it.
      cli = "all";

      # runs via gateway under hermes user.
      discord = [
        "web"
        "search"
        "tts"
        "vision"
        "skills"
        "file"
        "memory"
        "terminal"
      ];

      # runs cli under hermes user
      cron = [
        "web"
        "search"
        "skills"
        "memory"
        "session_search"
        "terminal"
      ];
    };
  };
}

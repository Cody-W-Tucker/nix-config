let
  # Default is the general operator, not the universal control plane.
  # Scheduled runs and outgoing messaging remain deliberate profile-specific work.
  defaultToolsets = [
    "web"
    "search"
    "browser"
    "skills"
    "file"
    "memory"
    "session_search"
    "terminal"
  ];
in
{
  config.services.hermes-agent.settings = {
    # Gateway/CLI resolves active tools from platform_toolsets. Keep all
    # interactive default surfaces on the same bounded, general-purpose set.
    platform_toolsets = {
      api_server = defaultToolsets;
      telegram = defaultToolsets;
      cli = defaultToolsets;
      discord = defaultToolsets;

      # Execution surface for already-created scheduled work; cronjob management
      # is intentionally not exposed in the ordinary default conversation.
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

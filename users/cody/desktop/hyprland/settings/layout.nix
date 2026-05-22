{ hardwareConfig, ... }:

let
  webApp = "uwsm app -- chromium --new-window --app";
  terminal = "uwsm app -- kitty";

  # Special workspaces keep the old intent, but in workspace_rule shape
  specialWorkspaceRules = [
    {
      workspace = "special:ai";
      on_created_empty = "${webApp}=https://www.perplexity.ai/";
    }
    {
      workspace = "special:dev";
      on_created_empty = terminal;
    }
    {
      workspace = "special:media";
      on_created_empty = "${webApp}=https://www.youtube.com/";
    }
    {
      workspace = "special:think";
      on_created_empty = "${webApp}=https://draw.homehub.tv/";
    }
  ];
in
{
  wayland.windowManager.hyprland.settings = {
    workspace_rule = hardwareConfig.workspace ++ specialWorkspaceRules;
    monitor = hardwareConfig.monitor;
  };
}

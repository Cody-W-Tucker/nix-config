{ config, ... }:

let
  pluginPath = "${config.xdg.configHome}/opencode/plugins/session-headers.ts";
in
{
  # Install next to rtk/model-router; OpenCode loads plugins from this dir and
  # from programs.opencode.settings.plugin (explicit path for reliability).
  home.file.".config/opencode/plugins/session-headers.ts".source = ./plugin.ts;

  programs.opencode.settings.plugin = [ pluginPath ];
}

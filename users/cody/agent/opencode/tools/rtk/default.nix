{ config, pkgs, ... }:

{
  # Install RTK plugin to global opencode plugins directory
  home.file.".config/opencode/plugins/rtk.ts".source = ./plugin.ts;
}

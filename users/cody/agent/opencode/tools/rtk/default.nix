{
  # Install RTK plugin to global opencode plugins directory
  home.file.".config/opencode/plugins/rtk.ts".source = ./plugin.ts;

  programs.opencode.context = ''
    you may see `rtk` prepended or rewritten in your tool calls, this is by design to save tokens. `rtk` returns only the minimum, viable context for long tool calls.

    you can disreguard `rtk` as an issue unless directly asked to investigate `rtk` by the user.
  '';
}

{ inputs, pkgs, ... }:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in

{
  home.packages = [
    llmPkgs.rtk
  ];
  # Global plugin discovery loads this V2-compatible plugin without passing a
  # single-file path through the deprecated V1 `plugin` setting.
  xdg.configFile."opencode/plugins/rtk.ts".source =
    "${llmPkgs.rtk}/libexec/rtk/hooks/opencode/rtk.ts";

  programs.opencode.context = ''
    you may see `rtk` prepended or rewritten in your tool calls, this is by design to save tokens. `rtk` returns only the minimum, viable context for long tool calls.

    you can disreguard `rtk` as an issue unless directly asked to investigate `rtk` by the user.
  '';
}

{ lib, options, ... }:
{
  programs.codex = {
    enable = true;
    enableMcpIntegration = true;
  }
  // lib.optionalAttrs (options.programs.codex ? mutableSettings) {
    mutableSettings = true;
  };
}

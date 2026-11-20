{ lib, options, ... }:
{
  programs.codex = {
    enable = true;
    enableMcpIntegration = true;
  }
  # The stable module writes a managed config and backs up any existing file.
  // lib.optionalAttrs (options.programs.codex ? mutableSettings) {
    mutableSettings = true;
  };
}

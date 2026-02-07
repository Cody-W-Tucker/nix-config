{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  programs.opencode = {
    enable = true;
    # Use most reccent package from flake
    package = inputs.opencode.packages.${pkgs.system}.default;
    settings.theme = lib.mkForce "system";
  };
}

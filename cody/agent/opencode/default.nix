{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./scripts
    ./taskwarrior.nix
  ];

  programs.opencode = {
    enable = true;
    # Use most reccent package from flake
    package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings.theme = lib.mkForce "system";
    enableMcpIntegration = true;
  };
}

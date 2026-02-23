{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  scriptNames = [
    ./opencode-task.nix
    ./rofi-opencode.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  imports = [
    ./taskwarrior.nix
  ];

  home.packages = scriptPackages;

  programs.opencode = {
    enable = true;
    # Use most reccent package from flake
    package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings.theme = lib.mkForce "system";
    enableMcpIntegration = true;
  };
}

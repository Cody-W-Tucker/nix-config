{ pkgs, ... }:

let
  scriptNames = [
    ./focus-or-run.nix
    ./kanban-launcher.nix
    ./project.nix
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./task-runner.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  imports = [
    ./kanban-watcher.nix
  ];

  home.packages = scriptPackages;

  # Enable kanban watcher service
  services.kanban-watcher.enable = true;
}

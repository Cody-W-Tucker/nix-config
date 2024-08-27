{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./mako.nix
    ./nixvim.nix
    ./rofi.nix
    ./waybar.nix
    ./xdg.nix
  ];

  home.packages = with pkgs; [
    # Add some packages to the user environment.
    grim
    slurp
    wl-clipboard
    hyprpicker
    mako
    swww
    rofi-wayland
    vscode
    zotero
    gh
    ripdrag
    spotify
    tectonic
  ];

  # Clipboard history
  services.cliphist.enable = true;

  # Document handling
  programs.pandoc = {
    enable = true;
    defaults = {
      metadata = {
        author = "Cody W Tucker";
      };
      pdf-engine = "tectonic";
    };
  };
}

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
    blueman
    (texlive.combine
      {
        inherit (pkgs.texlive) scheme-small
          # Add any additional packages you need
          pgf
          standalone;
      })
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
      pdf-engine = "pdflatex";
    };
  };
}

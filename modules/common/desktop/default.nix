{ pkgs, config, lib, ... }: {

  imports = [
    ./services.nix
    ./printers.nix
  ];

  services.displayManager.autoLogin.enable = true;

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Default Display Manager and Windowing system.
  services = {
    # Set up the X11 windowing system.
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      xkb = {
        layout = "us";
        model = "pc105";
      };
    };
  };

  # Enable the Hyprland Desktop Environment.
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  #xdg  
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal
    ];
    configPackages = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal
    ];
  };

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    google-chrome
    firefox
    obsidian
    feh
    zathura
    pavucontrol
    polkit_gnome
    xdg-utils # xdg-open
    libreoffice
    hunspell
    vlc
  ];

}

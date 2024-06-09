{ pkgs, config, inputs, ... }: {

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    nixpkgs-fmt
    firefox
    lf
    ranger
    gnome.nautilus
    feh
    zathura
    docker-compose
    pavucontrol
    polkit_gnome
    xdg-utils # xdg-open
    # Removable media, daemons defined in system/services.nix
    usbutils
    udiskie
    udisks
    libreoffice-qt
    hunspell
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    vlc
    libvlc
    unzip
    where-is-my-sddm-theme # If I forget, the package name is hyphenated, the sddm theme is underscored
  ];

  # System wide terminal configuration
  programs = {
    zsh.enable = true;
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      defaultEditor = true;
    };
  };

  # Enable the Hyprland Desktop Environment.
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    xwayland.enable = true;
  };

}

# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      ./secrets/secrets.nix
    ];

  # Networking
  networking.networkmanager.enable = true;
  services.displayManager.autoLogin.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  i18n = {
    # Select internationalisation properties.
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

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

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    git
    nixpkgs-fmt
    firefox
    lf
    ranger
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
    libreoffice
    hunspell
    vlc
    libvlc
    unzip
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.codyt = {
    isNormalUser = true;
    description = "Cody Tucker";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
    #  thunderbird
    ];
    openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkUAtqd1GcKYejbmpxjLzXdMoDojpVuNXEEBhYQjVgY cody@tmvsocial.com"
        ];
    };
  };
    users.users.jordant = {
    isNormalUser = true;
    description = "Jordan Tucker";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    # thunderbird
    ];
  };

  # Optimization settings and garbage collection automation
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}

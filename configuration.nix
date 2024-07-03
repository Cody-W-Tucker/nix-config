# This is the shared config for all machines

{ config, pkgs, inputs, ... }:

{
  imports =
    [
      ./secrets/secrets.nix
      ./modules/terminal.nix
    ];

  # Networking
  networking.networkmanager.enable = true;

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

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    git
    nixpkgs-fmt
    ranger
  ];

  # Make passwords uneditable
  users.mutableUsers = false;

  # # Create the passwords so they exist across all hosts
  # sops.secrets = {
  #   codyt = {
  #     neededForUsers = true;
  #   };
  #   jordant = {
  #     neededForUsers = true;
  #   };
  # };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.codyt = {
    isNormalUser = true;
    description = "Cody Tucker";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    #hashedPasswordFile = config.sops.secrets.codyt.path;
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
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
    shell = pkgs.zsh;
    #hashedPasswordFile = config.sops.secrets.jordant.path;
    hashedPassword = "$y$j9T$T1YkmagP6ULuI6DvQz8IK0$38YlfZN9eR1jH286/9kZn13flzy.wFtPX74ukXKJhM7";
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

  # Enable fail2ban to block brute-force attacks.
  services.fail2ban.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}

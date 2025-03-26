# This is the shared config for all machines

{ pkgs, ... }:

{
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
    starship
    (btop.override { cudaSupport = true; })
    wget
    chromium
  ];

  # Terminal defaults
  programs = {
    starship = {
      enable = true;
      presets = [ "nerd-font-symbols" ];
    };
    zsh = {
      enable = true;
      autosuggestions.enable = true;
    };
  };

  # Make passwords uneditable
  users.mutableUsers = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.codyt = {
    isNormalUser = true;
    description = "Cody Tucker";
    extraGroups = [ "networkmanager" "wheel" "docker" "media" "scanner" "lp" "bluetooth" ];
    shell = pkgs.zsh;
    # hashedPasswordFile = config.sops.secrets.codyt.path;
    hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
    openssh = {
      authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkUAtqd1GcKYejbmpxjLzXdMoDojpVuNXEEBhYQjVgY cody@tmvsocial.com"
      ];
    };
  };

  # Optimization settings and garbage collection automation
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Logrotate
  services.logrotate.enable = true;

  # Syncthing shared configuration
  services.syncthing.settings.devices = {
    "server" = { id = "RWUUJ5C-MDAHVZZ-M7FK6NB-W5WAWIX-QFFDD4G-7QAQWHG-73ZM7Y5-6X5YCQR"; };
    "workstation" = { id = "7YDHDRD-FYM5KFG-BKQLPGL-RFP6JFE-DXD27F4-HVJWV3A-TAKVJSX-LGNHNQM"; };
    "Cody's Pixel" = { id = "T3CJ4YF-RDXUROW-E7NZOKN-BZXE67E-NQWOHVO-UD5BCCS-2A6KONP-LTA5BQF"; };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  # Enable fail2ban for ssh protection
  services.fail2ban.enable = true;
}

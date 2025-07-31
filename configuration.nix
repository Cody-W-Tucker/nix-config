# This is the shared config for all machines

{ pkgs, ... }:

{
  config = {
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
      borgbackup
    ];

    # Terminal defaults
    programs = {
      starship = {
        enable = true;
      };
      zsh = {
        enable = true;
        # Disable the completion in the global module because it would call compinit
        # but the home manager config also calls compinit. This causes the cache to be invalidated
        # because the fpath changes in-between, causing constant re-evaluation and thus startup
        # times of 1-2 seconds. Disable the completion here and only keep the home-manager one to fix it.
        enableCompletion = false;
      };
    };

    # Installing system wide fonts
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        font-awesome
        source-han-sans
        nerd-fonts.meslo-lg
      ];
    };

    # Make passwords uneditable
    users.mutableUsers = false;

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.codyt = {
      isNormalUser = true;
      description = "Cody Tucker";
      extraGroups = [ "networkmanager" "wheel" "docker" "media" "scanner" "lp" "bluetooth" "input" "documents" "openrazer" ];
      shell = pkgs.zsh;
      # hashedPasswordFile = config.sops.secrets.codyt.path;
      hashedPassword = "$y$j9T$2gGzaHfv1JMUMtHdaXBGF/$RoEaBINI46v1yFpR1bSgPc9ovAyzqjgSSTxuNhRiOn4";
      openssh = {
        authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJkUAtqd1GcKYejbmpxjLzXdMoDojpVuNXEEBhYQjVgY cody@tmvsocial.com"
        ];
      };
    };

    # Create user groups for different services
    users.groups.media = { };
    users.groups.documents = { };

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
      "beast" = { id = "WS3XKRH-JILABRE-NLK2NU6-BGPXTOY-TOO2K75-UYEY7HB-KO7NKAC-I37UGQ3"; };
    };

    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    # Enable fail2ban for ssh protection
    services.fail2ban.enable = true;

    # Enable nftables firewall
    networking.nftables.enable = true;
  };
}

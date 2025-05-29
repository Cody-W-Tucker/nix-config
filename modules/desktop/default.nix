{ pkgs, pkgs-unstable, ... }: {

  imports = [
    ./clientSyncthing.nix
  ];

  services.displayManager.autoLogin.enable = true;

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Default Display Manager and Windowing system.
  services = {
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
    xwayland.enable = true;
    withUWSM = true;
  };

  environment.systemPackages =
    (with pkgs; [
      # list of stable packages go here
      feh
      zathura
      pavucontrol
      xdg-utils # xdg-open
      vlc
      usbutils
      udiskie
      udisks
      kitty
      obsidian
      chromium
      rustdesk-flutter
    ]);

  # Open ports for rustdesk
  networking.firewall.allowedTCPPorts = [ 21115 21116 21117 21118 21119 ];
  networking.firewall.allowedUDPPorts = [ 21115 21116 21117 21118 21119 ];

  programs.firefox = {
    enable = true;
    package = pkgs-unstable.firefox;
  };

  # Enable support for removable devices.
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  # Bluetooth support
  hardware = {
    bluetooth = {
      enable = true;
      package = pkgs-unstable.bluez5-experimental;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true; # Enable experimental features
          FastConnectable = true; # Improve connection speed
          JustWorksRepairing = "always";
          controllerMode = "bredr"; # Allow low energy mode?
          MultiProfile = "multiple"; # Allow multiple profiles
          AutoEnable = true;
        };
      };
    };
  };

  # Enable sound with pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true; # Required for priority rules
    wireplumber.extraConfig = {
      "bluetooth-no-mic" = {
        "monitor.bluez.rules" = [
          {
            matches = [
              { "node.name" = "~bluez_input.*"; }
            ];
            actions = {
              "remove" = true;
            };
          }
        ];
      };
    };
  };

  services.upower.enable = true;
}

{ pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./clientSyncthing.nix
  ];
  config = {

    environment.systemPackages =
      (with pkgs; [
        # list of stable packages go here
        feh # Image viewer
        zathura # PDF viewer
        pavucontrol # PulseAudio volume control
        xdg-utils # xdg-open
        usbutils # For listing USB devices
        udiskie # For mounting USB devices
        udisks # For managing disks
        kitty # Terminal emulator
        obsidian # Note-taking app
        rustdesk-flutter # Remote desktop software
        mpv # Media player
        cifs-utils # For mounting CIFS shares
      ]);

    # Open ports for rustdesk
    networking.firewall.allowedTCPPorts = [ 21115 21116 21117 21118 21119 ];
    networking.firewall.allowedUDPPorts = [ 21115 21116 21117 21118 21119 ];

    # Enable mullvad VPN
    services.mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };

    # Default browser on the system
    programs.firefox = {
      enable = true;
      package = pkgs-unstable.firefox;
    };

    # Allows nautilus to access gvfs mounts (trash and samba shares)
    services.gvfs.enable = true;

    # Enable support for removable devices.
    services.udisks2.enable = true;

    # Provides a way to manage system firmware updates
    services.fwupd.enable = true;

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
      wireplumber.enable = true; # Required for priority rules in host specific configs
    };
  };
}

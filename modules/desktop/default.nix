{ pkgs, ... }:

{
  imports = [
    ./audio.nix
    ../syncthing.nix
    ./logging.nix
  ];

  hardware.graphics.enable = true;

  services = {
    # Provides a way to manage system firmware updates
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };
    # Allows nautilus (gnome files) to access gvfs mounts (trash and samba shares)
    gvfs.enable = true;
    # Enable support for removable devices.
    udisks2.enable = true;
  };

  # Install basic desktop environment packages that I want on all my systems.
  environment.systemPackages = (
    with pkgs;
    [
      # list of stable packages go here
      pavucontrol # PulseAudio volume control
      xdg-utils # xdg-open
      usbutils # For listing USB devices
      udiskie # For mounting USB devices
      udisks # For managing disks
      udev # Device manager
      kitty # Terminal emulator
      obsidian # Note-taking app
      rustdesk-flutter # Remote desktop software
      cifs-utils # For mounting CIFS shares
      seahorse # GNOME keyring manager
      openrazer-daemon # Razer device support
      go-chromecast # Chromecast CLI tool
      wf-recorder # Wayland screen recorder
      jq # JSON parsing for hyprctl
      netcat # Port checking for chromecast
    ]
  );

  # Open ports for rustdesk and chromecast streaming
  networking.firewall.allowedTCPPorts = [
    21115
    21116
    21117
    21118
    21119
    8384 # Syncthing GUI
    22000 # Syncthing sync protocol
    8080 # Chromecast screen streaming
  ];
  networking.firewall.allowedUDPPorts = [
    21115
    21116
    21117
    21118
    21119
    22000 # Syncthing sync protocol
    21027 # Syncthing local discovery
  ];
}

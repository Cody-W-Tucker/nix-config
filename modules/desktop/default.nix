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

    # Avahi for AirPlay mDNS discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
  };

  # uxplay: AirPlay server
  systemd.user.services.uxplay = {
    description = "uXPlay AirPlay Server";
    wantedBy = [ "hyprland-session.target" ]; # Auto-start on Hyprland
    serviceConfig = {
      ExecStart = "${pkgs.uxplay}/bin/uxplay -v --no-video-ads";
      Restart = "always";
    };
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
      uxplay # AirPlay server
    ]
  );

  # Open ports for rustdesk and AirPlay
  networking.firewall.allowedTCPPorts = [
    21115
    21116
    21117
    21118
    21119
    8384 # Syncthing GUI
    22000 # Syncthing sync protocol
    # AirPlay (uxplay)
    5000
    7000
    7100
    9000
  ];
  networking.firewall.allowedUDPPorts = [
    21115
    21116
    21117
    21118
    21119
    22000 # Syncthing sync protocol
    21027 # Syncthing local discovery
    # AirPlay (uxplay)
    5353
    5351
    7000
  ];
}

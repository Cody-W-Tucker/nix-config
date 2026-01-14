{ pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./audio.nix
    ./clientSyncthing.nix
    ./logging.nix
  ];

  hardware.graphics.enable = true;

  services = {
    # Provides a way to manage system firmware updates
    fwupd.enable = true;
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
    ]
  );

  # Open ports for rustdesk
  networking.firewall.allowedTCPPorts = [
    21115
    21116
    21117
    21118
    21119
  ];
  networking.firewall.allowedUDPPorts = [
    21115
    21116
    21117
    21118
    21119
  ];

  # Default browser on the system
  programs.firefox = {
    enable = true;
    package = pkgs-unstable.firefox;
  };
}

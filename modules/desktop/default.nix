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
  environment.systemPackages = with pkgs; [
    # list of stable packages go here
    pavucontrol # PulseAudio volume control
    xdg-utils # xdg-open
    usbutils # For listing USB devices
    udiskie # For mounting USB devices
    udisks # For managing disks
    udev # Device manager
    kitty # Terminal emulator
    obsidian # Note-taking app
    cifs-utils # For mounting CIFS shares
    seahorse # GNOME keyring manager
    openrazer-daemon # Razer device support
  ];

  networking.firewall.allowedTCPPorts = [
    8384 # Syncthing GUI
    22000 # Syncthing sync protocol
  ];
  networking.firewall.allowedUDPPorts = [
    22000 # Syncthing sync protocol
    21027 # Syncthing local discovery
  ];
}

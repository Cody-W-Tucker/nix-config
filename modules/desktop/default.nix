{ pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./audio.nix
    ./clientSyncthing.nix
    ./logging.nix
  ];

  # Enable OpenGL
  hardware.graphics.enable = true;

  # Enable OpenRazer for keyboard and mouse support
  hardware.openrazer.enable = true;

  # Allow redistributable firmware
  hardware.enableRedistributableFirmware = true;

  # Install Bluetooth firmware for realtek dongles
  hardware.firmware = [
    pkgs.rtl8761b-firmware
  ];

  # Provides a way to manage system firmware updates
  services.fwupd.enable = true;

  # Install basic desktop environment packages that I want on all my systems.
  environment.systemPackages =
    (with pkgs; [
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
    ]);

  # Open ports for rustdesk
  networking.firewall.allowedTCPPorts = [ 21115 21116 21117 21118 21119 ];
  networking.firewall.allowedUDPPorts = [ 21115 21116 21117 21118 21119 ];

  # Enable mullvad VPN app
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  # Default browser on the system
  programs.firefox = {
    enable = true;
    package = pkgs-unstable.firefox;
  };

  # Allows nautilus (gnome files) to access gvfs mounts (trash and samba shares)
  services.gvfs.enable = true;

  # Enable support for removable devices.
  services.udisks2.enable = true;
}

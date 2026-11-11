{ pkgs, ... }:

{
  imports = [
    ./audio
    ./hyprland.nix
    ./logging.nix
    ./printing.nix
    ../services/syncthing.nix
    ./hardware/nvidia.nix
    ./hardware/wifi.nix
    ./vpn
  ];

  hardware.graphics.enable = true;

  services = {
    # Allows nautilus (gnome files) to access gvfs mounts (trash and samba shares)
    gvfs.enable = true;
  };

  # Install basic desktop environment packages that I want on all my systems.
  environment.systemPackages = with pkgs; [
    pavucontrol # PulseAudio volume control
    xdg-utils # xdg-open
    usbutils # For listing USB devices
    seahorse # GNOME keyring manager
    gcr_3 # GNOME Keyring unlock prompt provider
  ];

  # Syncthing ports come from modules/services/syncthing.nix.
  networking.firewall = {
    # Open firewall ports for KDE Connect discovery
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
  };
}

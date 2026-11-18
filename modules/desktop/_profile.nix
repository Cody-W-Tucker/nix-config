{ pkgs, ... }:

{
  imports = [
    ./_audio.nix
    ./_fonts.nix
    ./_hyprland-system.nix
    ./_logging.nix
    ./_printing.nix
    ./_nvidia-session.nix
    ./_wifi.nix
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

  # Syncthing comes from den.aspects.syncthing (modules/services/syncthing.nix).
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

{ den, ... }:
{
  # Desktop role (beast): Hyprland session, audio, fonts, printing, theming and the user's
  # desktop applications. Each concern is its own aspect in this directory; gaming and
  # openrazer are opt-in and included by the host.
  den.aspects.desktop = {
    includes = [
      den.aspects.syncthing
      den.aspects.audio
      den.aspects.fonts
      den.aspects.hyprland
      den.aspects.desktop-logging
      den.aspects.printing
      den.aspects.nvidia-session
      den.aspects.wifi
      den.aspects.kdeconnect
      den.aspects.theming
      den.aspects.terminal
      den.aspects.wayland-session
      den.aspects.desktop-apps
      den.aspects.desktop-scripts
      den.aspects.browser
      den.aspects.notifications
      den.aspects.rofi
      den.aspects.waybar
      den.aspects.speech-to-text
      den.aspects.obsidian
      den.aspects.xdg
      den.aspects.programs
    ];

    nixos =
      { pkgs, ... }:
      {
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
      };
  };
}

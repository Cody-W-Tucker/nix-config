{ config, lib, ... }:
let
  session = {
    command = "${lib.getExe config.programs.uwsm.package} start hyprland.desktop";
    user = "codyt";
  };
in
{
  # Enable the Hyprland Desktop Environment.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  security.pam.services = {
    # Enable PAM support for Hyprlock so it unlock the screen correctly
    hyprlock = { };
    # Enable a keyring service for storing secrets
    login.enableGnomeKeyring = true;
  };

  # Use Greetd to launch Hyprland from TTY2
  services = {
    greetd = {
      enable = true;
      # do not restart on session exit (useful on autologin)
      restart = false;
      settings = {
        terminal.vt = 1;
        initial_session = session;
        default_session = session;
      };
    };
  };
}

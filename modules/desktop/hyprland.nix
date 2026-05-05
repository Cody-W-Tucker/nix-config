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
    # Keyring auto-unlock on greetd login (this is the missing piece for most greetd users)
    greetd.enableGnomeKeyring = true;
  };

  # Use Greetd to launch Hyprland from TTY2
  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "uwsm start hyprland-uwsm.desktop";
          user = "codyt";
        };
      };
    };
  };
}

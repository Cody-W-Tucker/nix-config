{ ... }:

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

  environment.sessionVariables = {
    # Set the session name for Hyprland to fix strange session issues
    DESKTOP_SESSION = "hyprland";
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

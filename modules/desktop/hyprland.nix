{
  # Enable the Hyprland Desktop Environment.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
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
      vt = 2;
    };
  };
}

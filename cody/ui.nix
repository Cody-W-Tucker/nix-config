{ pkgs, config, inputs, lib, ... }:

{
  imports = [
    ./ui
    ./cli
  ];

  # Keyboard
  home.keyboard = {
    layout = "us";
    model = "pc105";
  };

  # Consider moving some of these to system environment variables
  home.sessionVariables = {
    BROWSER = "google-chrome";
    VISUAL = "nvim";
    TERMINAL = "kitty";
    VDPAU_DRIVER = "va_gl";
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
  };

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}

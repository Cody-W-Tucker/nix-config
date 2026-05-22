{ ... }:

{
  wayland.windowManager.hyprland.settings.window_rule = [
    # Kitty
    {
      match = {
        class = "^(kitty)$";
      };
      no_blur = true;
    }
    {
      match = {
        class = "^(kitty)$";
      };
      opacity = "1.0 1.0 1.0 override";
    }

    # Ensure all web apps don't float
    {
      match = {
        initial_class = "^(Chromium-browser)$";
      };
      tile = true;
    }
    {
      match = {
        title = "^(Picture-in-Picture)$";
      };
      float = true;
    }
    {
      match = {
        title = "^(Picture-in-Picture)$";
      };
      pin = true;
    }

    # Throw sharing indicators away
    {
      match = {
        title = "^(Firefox — Sharing Indicator)$";
      };
      workspace = "special silent";
    }
    {
      match = {
        title = "^(Zen — Sharing Indicator)$";
      };
      workspace = "special silent";
    }
    {
      match = {
        title = "^(.*is sharing (your screen|a window).)$";
      };
      workspace = "special silent";
    }
  ];
}

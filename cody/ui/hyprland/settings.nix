let
  mainMod = "SUPER";

  mousebinds = [
    # Move/resize windows with mainMod + LMB/RMB and dragging
    "${mainMod}, mouse:272, movewindow"
    "${mainMod}, mouse:273, resizewindow"
  ];

  keybinds = [
    # Application launchers
    "${mainMod}, V, exec, uwsm app -- cliphist list | rofi -dmenu | cliphist decode | wl-copy"
    "${mainMod}, Q, exec, uwsm app -- kitty"
    "${mainMod}, E, exec, uwsm app -- kitty -- ranger"
    "${mainMod} SHIFT, Tab, exec, uwsm app -- rofi-launcher"
    "${mainMod}, Tab, exec, uwsm app -- web-search"
    "${mainMod} SHIFT, E, exec, uwsm app -- nautilus"
    "${mainMod} SHIFT, Q, exec, uwsm app -- rofi -show web_scraper -modi 'web_scraper:web-scraper'"
    "${mainMod}, KP_Enter, exec, uwsm app -- taskwarrior-rofi quick_add"
    "${mainMod} SHIFT, KP_Enter, exec, uwsm app -- taskwarrior-rofi"

    # Quick launch apps
    "${mainMod}, KP_Insert, exec, uwsm app -- firefoxpwa site launch 01JKS3GVGR2ZK2ZNMH5X913QP7"
    "${mainMod}, KP_Add, exec, uwsm app -- hyprctl dispatch exec [floating] gnome-calculator"
    "${mainMod}, KP_Home, exec, uwsm app -- code"
    "${mainMod} SHIFT, KP_Home, exec, uwsm app -- cursor"

    # Screenshots
    ''${mainMod}, S, exec, uwsm app -- grim -g "$(slurp)" "$HOME/Pictures/Screenshots/$(date '+%y%m%d_%H-%M-%S').png"''
    ''${mainMod} SHIFT, S, exec, uwsm app -- grim -g "$(slurp)" - | wl-copy''

    # Color picker
    "${mainMod}, mouse:274, exec, uwsm app -- hyprpicker -a"

    # Workspace navigation
    "${mainMod}, mouse_down, exec, uwsm app -- hyprnome --previous"
    "${mainMod}, mouse_up, exec, uwsm app -- hyprnome"
    "${mainMod} SHIFT, mouse_down, exec, uwsm app -- hyprnome --previous --move"
    "${mainMod} SHIFT, mouse_up, exec, uwsm app -- hyprnome --move"

    # Window management
    "${mainMod}, SPACE, togglefloating"
    "${mainMod}, C, killactive"
    "${mainMod}, F, fullscreen"
    "${mainMod} SHIFT, P, fullscreenstate"
    "${mainMod}, P, pin"

    # Focus movement
    "${mainMod}, left, movefocus, l"
    "${mainMod}, right, movefocus, r"
    "${mainMod}, up, movefocus, u"
    "${mainMod}, down, movefocus, d"

    # Window movement
    "${mainMod} SHIFT, left, movewindow, l"
    "${mainMod} SHIFT, right, movewindow, r"
    "${mainMod} SHIFT, up, movewindow, u"
    "${mainMod} SHIFT, down, movewindow, d"

    # Scratchpad
    "${mainMod}, A, togglespecialworkspace, magic"
    "${mainMod} SHIFT, A, movetoworkspacesilent, special:magic"

    # Gromit Screendrawing
    "${mainMod}, F9, exec, pidof gromit-mpx && gromit-mpx -q || gromit-mpx -a"
  ];
in
{
  wayland.windowManager.hyprland.settings = {
    "$mainMod" = mainMod;
    bindm = mousebinds;
    bind = keybinds;
    windowrule = [
      # Gromit
      "noblur, ^(Gromit-mpx)$"
      "opacity 1 override, 1 override, ^(Gromit-mpx)$"
      "noshadow, ^(Gromit-mpx)$"
      "suppressevent fullscreen, ^(Gromit-mpx)$"
      "size 100% 100%, ^(Gromit-mpx)$"
      # Kitty
      "noblur,^(kitty)$"
    ];
    windowrulev2 = [
      "float, title:^(Picture-in-Picture)$"
      "pin, title:^(Picture-in-Picture)$"

      # throw sharing indicators away
      "workspace special silent, title:^(Firefox — Sharing Indicator)$"
      "workspace special silent, title:^(Zen — Sharing Indicator)$"
      "workspace special silent, title:^(.*is sharing (your screen|a window)\.)$"
    ];
  };
  # Screen drawing
  services.gromit-mpx = {
    enable = true;
    opacity = 1.0;
  };
}

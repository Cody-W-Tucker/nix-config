{config, lib, hardwareConfig, ...}:

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
    "${mainMod}, Q, exec, uwsm app -- nvidia-offload kitty"
    "${mainMod}, E, exec, uwsm app -- nvidia-offload kitty ranger"
    "${mainMod} SHIFT, Tab, exec, uwsm-app -- rofi-launcher"
    "${mainMod}, Tab, exec, uwsm app -- web-search"
    "${mainMod} SHIFT, E, exec, uwsm-app -- nautilus"
    "${mainMod}, KP_Enter, exec, uwsm app -- taskwarrior-rofi quick_add"
    "${mainMod}, Return, exec, uwsm app -- taskwarrior-rofi quick_add"
    "${mainMod} SHIFT, KP_Enter, exec, uwsm app -- taskwarrior-rofi"
    "${mainMod} SHIFT, Return, exec, uwsm app -- taskwarrior-rofi"
    "${mainMod}, GRAVE, exec, uwsm app -- todoist-rofi quick_add"

    # Quick launch apps
    "${mainMod}, KP_Insert, exec, uwsm-app -- nvidia-offload zen"
    "${mainMod}, KP_Add, exec, uwsm-app -- hyprctl dispatch exec [floating] gnome-calculator"
    "${mainMod}, KP_Home, exec, uwsm-app -- code"
    "${mainMod} SHIFT, KP_Home, exec, uwsm-app -- cursor"

    # Screenshots
    ''${mainMod}, S, exec, uwsm app -- screenshot-ocr''
    ''${mainMod} SHIFT, S, exec, uwsm app -- grim -g "$(slurp)" - | wl-copy''

    # Color picker
    "${mainMod}, mouse:274, exec, uwsm-app -- hyprpicker -a"

    # Workspace navigation
    "${mainMod}, mouse_down, exec, uwsm-app -- hyprnome --previous"
    "${mainMod}, mouse_up, exec, uwsm-app -- hyprnome"
    "${mainMod} SHIFT, mouse_down, exec, uwsm-app -- hyprnome --previous --move"
    "${mainMod} SHIFT, mouse_up, exec, uwsm-app -- hyprnome --move"

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

      # Handle fullscreen inside of hyprland instead of the app
      # Will make fullscreen event 
      "fullscreenstate 0 2,class:(firefox)"
      "fullscreenstate 0 2,class:(zen)"
      "fullscreenstate 0 2,class:(chromium-browser)"

      # throw sharing indicators away
      "workspace special silent, title:^(Firefox — Sharing Indicator)$"
      "workspace special silent, title:^(Zen — Sharing Indicator)$"
      "workspace special silent, title:^(.*is sharing (your screen|a window)\.)$"
    ];
    # Workspace and monitor set in flake.nix
      workspace = hardwareConfig.workspace;
      monitor = hardwareConfig.monitor;
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 5, myBezier"
          "windowsOut, 1, 4, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 5, default"
          "workspaces, 1, 5, default"
        ];
      };
      input = {
        numlock_by_default = "true";
        follow_mouse = "1";
        sensitivity = "-.7";
        kb_layout = "us";
      };
      general = {
        border_size = "2";
        gaps_in = "5";
        gaps_out = "5";
        layout = "master";
        "col.active_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base0C}aa) rgba(${config.lib.stylix.colors.base0D}aa) rgba(${config.lib.stylix.colors.base0B}aa) rgba(${config.lib.stylix.colors.base0E}aa) 45deg";
        "col.inactive_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base00}99) rgba(${config.lib.stylix.colors.base01}99) 45deg";
      };
      cursor.hide_on_key_press = true;
      decoration = {
        rounding = "10";
        active_opacity = "0.95";
        inactive_opacity = "0.75";
        blur = {
          enabled = "true";
          size = "10";
          passes = "3";
          new_optimizations = "true";
          ignore_opacity = true;
          noise = "0";
          brightness = "0.60";
        };
        shadow = {
          enabled = true;
          render_power = "3";
          range = "4";
          color = lib.mkForce "rgba(1a1a1aee)";
        };
      };
      dwindle = {
        pseudotile = "yes";
        preserve_split = "yes";
      };
      master = {
        new_status = "master";
      };
      gestures = {
        workspace_swipe = "off";
      };
      misc = {
        mouse_move_enables_dpms = "true";
        key_press_enables_dpms = "true";
        force_default_wallpaper = "0";
        disable_hyprland_logo = lib.mkForce "true";
        focus_on_activate = "true";
      };
  };
  # Screen drawing
  services.gromit-mpx = {
    enable = true;
    opacity = 1.0;
  };
}

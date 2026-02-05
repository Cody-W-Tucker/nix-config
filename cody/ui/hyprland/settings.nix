{
  config,
  lib,
  hardwareConfig,
  ...
}:

let
  mainMod = "SUPER";
  browser = "uwsm app -- zen --new-tab";
  webApp = "uwsm app -- chromium --new-window --app";
  terminal = "uwsm app -- kitty";

  mousebinds = [
    # Move/resize windows with mainMod + LMB/RMB and dragging
    "${mainMod}, mouse:272, movewindow"
    "${mainMod}, mouse:273, resizewindow"
  ];

  specialWorkspaces = [
    "special:ai, on-created-empty: ${webApp}=https://www.perplexity.ai/"
    "special:dev, on-created-empty: ${terminal}"
    "special:media, on-created-empty: ${webApp}=https://www.youtube.com/"
  ];

  keybinds = [
    # Application launchers
    "${mainMod}, Q, exec, ${terminal}"
    "${mainMod}, 0, exec, ${browser}"

    # Web applications
    "${mainMod} SHIFT, Return, exec, [workspace special:ai] ${webApp}=https://grok.com/"
    "${mainMod}, A, exec, ${webApp}=https://ai.homehub.tv/"

    # Quick launch
    "${mainMod}, Tab, exec, rofi-launcher"
    "${mainMod}, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
    "${mainMod} SHIFT, Tab, exec, web-search"
    "${mainMod}, backslash, exec, rofi-opencode"
    "${mainMod}, BackSpace, exec, rofi -show calc -modi calc -no-show-match -no-sort -calc-command 'echo -n \"{result}\" | wl-copy'"

    # Task Management
    "${mainMod}, T, exec, ${terminal} --class taskwarrior-tui -e taskwarrior-tui"
    "${mainMod} SHIFT, T, exec, opencode-task"

    # Screenshots
    "${mainMod}, S, exec, screenshot-ocr"
    ''${mainMod} SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''

    # Color picker
    "${mainMod}, mouse:274, exec, hyprpicker -a"

    # Window management
    "${mainMod}, C, killactive"
    "${mainMod}, F, fullscreen"

    # Workspace navigation
    "${mainMod}, H, movefocus, l"
    "${mainMod} SHIFT, H, exec, hyprnome --previous --move"
    "${mainMod}, L, movefocus, r"
    "${mainMod} SHIFT, L, exec, hyprnome --move"

    "${mainMod}, mouse_down, exec, hyprnome --previous"
    "${mainMod}, mouse_up, exec, hyprnome"
    "${mainMod} SHIFT, mouse_down, exec, hyprnome --previous --move"
    "${mainMod} SHIFT, mouse_up, exec, hyprnome --move"

    # Special workspaces
    "${mainMod}, RETURN, togglespecialworkspace, ai"
    "${mainMod}, D, togglespecialworkspace, dev"
    "${mainMod}, Y, togglespecialworkspace, media"
    "${mainMod} SHIFT, Y, movetoworkspacesilent, special:media"

    # Toggle waybar
    "${mainMod}, W, exec, pkill -SIGUSR1 waybar"
  ];
in
{
  wayland.windowManager.hyprland.settings = {
    ecosystem = {
      no_update_news = true;
      no_donation_nag = true;
    };
    "$mainMod" = mainMod;
    bindm = mousebinds;
    bind =
      keybinds
      ++ (
        # workspaces
        # binds $mainMod + [shift +] {1..9} to [move to] workspace {1..9}
        builtins.concatLists (
          builtins.genList (
            i:
            let
              ws = i + 1;
            in
            [
              "${mainMod}, code:1${toString i}, workspace, ${toString ws}"
              "${mainMod} SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          ) 9
        )
      );
    bindel = [
      # Multimedia keys for volume and LCD brightness
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
      ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
    ];

    bindl = [
      # Requires playerctl
      ", XF86AudioNext, exec, playerctl next"
      ", XF86AudioPause, exec, playerctl play-pause"
      ", XF86AudioPlay, exec, playerctl play-pause"
      ", XF86AudioPrev, exec, playerctl previous"
    ];
    windowrule = [
      # Kitty
      {
        match = "class:^(kitty)$";
        noblur = true;
      }
      {
        match = "class:^(kitty)$";
        opacity = "1.0 1.0 1.0 override";
      }

      # Ensure all web apps don't float
      {
        match = "initialClass:^(Chromium-browser)$";
        tile = true;
      }

      {
        match = "title:^(Picture-in-Picture)$";
        float = true;
      }
      {
        match = "title:^(Picture-in-Picture)$";
        pin = true;
      }

      # Throw sharing indicators away
      {
        match = "title:^(Firefox — Sharing Indicator)$";
        workspace = "special silent";
      }
      {
        match = "title:^(Zen — Sharing Indicator)$";
        workspace = "special silent";
      }
      {
        match = "title:^(.*is sharing (your screen|a window).)$";
        workspace = "special silent";
      }

      # Customizing Obsidian
      {
        match = "class:^(obsidian)$";
        opacity = "0.99 0.99 0.99";
      }
      {
        match = "class:^(obsidian)$";
        noblur = true;
      }
      {
        match = "class:^(obsidian)$";
        noshadow = true;
      }
    ];

    # Workspace and monitor set in flake.nix
    workspace = hardwareConfig.workspace ++ specialWorkspaces;
    monitor = hardwareConfig.monitor;
    animations = {
      enabled = true;
      bezier = [
        "easeInExpo, 0.7, 0, 0.84, 0"
        "easeOutExpo, 0.16, 1, 0.3, 1"
      ];
      animation = [
        "windows, 1, 1, easeInExpo, slide"
        "windowsIn, 1, 1, easeInExpo, slide 80%"
        "windowsOut, 1, 1, easeOutExpo, slide 80%"
        "border, 1, 10, default"
        "borderangle, 1, 8, default"
        "fade, 1, 2, default"
        "workspaces, 0"
      ];
    };
    input = {
      numlock_by_default = "true";
      follow_mouse = "1";
      sensitivity = "-.7";
      force_no_accel = 0;
      kb_layout = "us";
    };
    debug = {
      full_cm_proto = true;
    };
    render = {
      cm_fs_passthrough = "2";
      direct_scanout = "2";
    };
    general = {
      border_size = "2";
      gaps_in = "2";
      gaps_out = "2";
      layout = "master";
      "col.active_border" =
        lib.mkForce "rgba(${config.lib.stylix.colors.base0C}aa) rgba(${config.lib.stylix.colors.base0D}aa) rgba(${config.lib.stylix.colors.base0B}aa) rgba(${config.lib.stylix.colors.base0E}aa) 45deg";
      "col.inactive_border" =
        lib.mkForce "rgba(${config.lib.stylix.colors.base00}99) rgba(${config.lib.stylix.colors.base01}99) 45deg";
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
    misc = {
      mouse_move_enables_dpms = "true";
      key_press_enables_dpms = "true";
      force_default_wallpaper = "0";
      disable_hyprland_logo = lib.mkForce "true";
      focus_on_activate = "true";
    };
  };
}

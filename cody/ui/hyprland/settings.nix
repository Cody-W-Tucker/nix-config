{ config, lib, hardwareConfig, ... }:

let
  mainMod = "SUPER";
  browser = "uwsm app -- chromium --new-window";
  webApp = browser + " --app";

  mousebinds = [
    # Move/resize windows with mainMod + LMB/RMB and dragging
    "${mainMod}, mouse:272, movewindow"
    "${mainMod}, mouse:273, resizewindow"
  ];

  keybinds = [
    # Application launchers
    "${mainMod}, Q, exec, uwsm app -- kitty"
    "${mainMod} SHIFT, E, exec, uwsm-app -- nautilus"
    "${mainMod}, 0, exec, uwsm app -- zen"
    "${mainMod}, 7, exec, uwsm app -- code"
    "${mainMod} SHIFT,7, exec, uwsm app -- cursor"

    # Web applications
    "${mainMod},O, exec, ${webApp}=https://ai.homehub.tv/"

    # Quick launch
    "${mainMod}, Tab, exec, rofi-launcher"
    "${mainMod}, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
    "${mainMod} SHIFT, Tab, exec, web-search"
    "${mainMod}, BackSpace, exec, rofi -show calc -modi calc -no-show-match -no-sort -calc-command 'echo -n '{result}' | wl-copy'"
    "${mainMod}SHIFT, Escape, exec, taskwarrior-rofi"
    "${mainMod}, Escape, exec, taskwarrior-rofi quick_add"
    "${mainMod}, RETURN, exec, todoist-rofi quick_add"

    # Screenshots
    ''${mainMod}, S, exec, screenshot-ocr''
    ''${mainMod} SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''

    # Color picker
    "${mainMod}, mouse:274, exec, hyprpicker -a"

    # Workspace navigation
    "${mainMod}, mouse_down, exec, hyprnome --previous"
    "${mainMod}, mouse_up, exec, hyprnome"
    "${mainMod} SHIFT, mouse_down, exec, hyprnome --previous --move"
    "${mainMod} SHIFT, mouse_up, exec, hyprnome --move"

    # Window management
    "${mainMod}, SPACE, togglefloating"
    "${mainMod}, C, killactive"
    "${mainMod}, F, fullscreen"

    # Focus movement
    "${mainMod}, h, movefocus, l"
    "${mainMod}, l, movefocus, r"
    "${mainMod}, k, movefocus, u"
    "${mainMod}, j, movefocus, d"

    # Window movement
    "${mainMod} SHIFT, h, movewindow, l"
    "${mainMod} SHIFT, l, movewindow, r"
    "${mainMod} SHIFT, k, movewindow, u"
    "${mainMod} SHIFT, j, movewindow, d"

    # Scratchpad
    "${mainMod}, A, togglespecialworkspace, magic"
    "${mainMod} SHIFT, A, movetoworkspacesilent, special:magic"

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
    bind = keybinds;
    windowrule = [
      # Kitty
      "noblur,class:kitty"
    ];
    windowrulev2 = [
      "float, title:^(Picture-in-Picture)$"
      "pin, title:^(Picture-in-Picture)$"

      # File switcher
      "float, class:^(kitty)$, title:^(quick-kitty)$"
      "size 1280 720, class:^(kitty)$, title:^(quick-kitty)$"
      "center, class:^(kitty)$, title:^(quick-kitty)$"

      # AI Chat
      "float, class:^(chrome-ai.homehub.tv__-Default)$, title:^(Open WebUI)$"
      "size 1280 720, class:^(chrome-ai.homehub.tv__-Default)$ title:^(Open WebUI)$"
      "center, class:^(chrome-ai.homehub.tv__-Default)$, title:^(Open WebUI)$"

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
      bezier = [
        "easeInExpo, 0.7, 0, 0.84, 0"
        "easeOutExpo, 0.16, 1, 0.3, 1"
      ];
      animation = [
        "windows, 1, 1, easeInExpo, slide"
        "windowsOut, 1, 1, easeOutExpo, slide"
        "border, 1, 10, default"
        "borderangle, 1, 8, default"
        "fade, 1, 2, default"
        "workspaces, 1, 2, default"
      ];
    };
    input = {
      numlock_by_default = "true";
      follow_mouse = "1";
      sensitivity = "-.7";
      force_no_accel = 0;
      kb_layout = "us";
    };
    experimental = {
      xx_color_management_v4 = true;
    };
    debug = {
      full_cm_proto = true;
    };
    render = {
      cm_fs_passthrough = "2";
      direct_scanout = "2";
    };
    device = {
      name = "apple-wireless-trackpad";
      sensitivity = "0.2";
      natural_scroll = "true";
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
}

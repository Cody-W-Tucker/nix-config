{ config, pkgs, lib, inputs, hardwareConfig, ... }:


{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd = {
      enable = true;
      variables = [
        "--all"
      ];
      extraCommands = [
        "systemctl --user stop hyprland-session.target"
        "systemctl --user start hyprland-session.target"
      ];
    };
    settings = {
      exec-once = [
        "mako"
        "dbus-update-activation-environment --systemd --all"
      ];
      workspace = hardwareConfig.workspace;
      cursor.no_hardware_cursors = true;
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };
      monitor = hardwareConfig.monitor;
      input = {
        numlock_by_default = "true";
        follow_mouse = "1";
        sensitivity = "-.7";
        kb_layout = "us";
      };
      general = {
        border_size = "2";
        gaps_in = "5";
        gaps_out = "20";
        layout = "master";
        "col.active_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base0C}ff) rgba(${config.lib.stylix.colors.base0D}ff) rgba(${config.lib.stylix.colors.base0B}ff) rgba(${config.lib.stylix.colors.base0E}ff) 45deg";
        "col.inactive_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base00}cc) rgba(${config.lib.stylix.colors.base01}cc) 45deg";
      };
      decoration = {
        rounding = "10";
        blur = {
          enabled = "true";
          size = "3";
          passes = "1";
          new_optimizations = "true";
          ignore_opacity = true;
        };
        drop_shadow = "yes";
        shadow_range = "4";
        shadow_render_power = "3";
        "col.shadow" = lib.mkForce "rgba(1a1a1aee)";
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
        disable_hyprland_logo = "true";
      };
      # Keybindings
      "$mainMod" = "SUPER";
      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
      bind =
        [
          "$mainMod, RETURN, exec, pkill waybar && waybar &"
          "$mainMod, Q, exec, kitty"
          "$mainMod, C, killactive"
          "$mainMod, E, exec, kitty -- ranger"
          "$mainMod SHIFT, E, exec, nautilus"
          "$mainMod, V, togglefloating"
          "$mainMod, Tab, exec, rofi-launcher"
          "$mainMod, F, fullscreen"
          # Number keys (0, -, +)
          "$mainMod, KP_Insert, exec, google-chrome-stable --app=https://ai.homehub.tv"
          "$mainMod, KP_Add, exec, hyprctl dispatch exec [floating] gnome-calculator"
          "$mainMod, KP_Enter, exec, google-chrome-stable --app=https://task-input-tmv.vercel.app/tasks"
          "$mainMod, KP_Subtract, exec, google-chrome-stable --app=https://recorder.google.com/"
          # Number keys (1, 2, 3)
          "$mainMod, KP_End, exec, google-chrome-stable --app=https://mail.google.com"
          "$mainMod, KP_Down, exec, google-chrome-stable --app=https://messages.google.com/web/u/0/conversations"
          "$mainMod, KP_Next, exec, google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r"
          # Number keys (4, 5, 6)
          "$mainMod, KP_Left, exec, google-chrome-stable --app=https://trello.com/u/codywt/boards"
          "$mainMod, KP_Begin, exec, google-chrome-stable --app=https://app.reclaim.ai/planner?taskSort=schedule"
          "$mainMod, KP_Right, exec, google-chrome-stable --app=https://tmvsocial.harvestapp.com/time/week"
          # Number keys (7, 8, 9)
          "$mainMod, KP_Home, exec, code"
          # Skipped 8 KP_Up
          "$mainMod, KP_Prior, exec, google-chrome-stable --app=https://tmv-social.odoo.com/web?action=277&model=account.journal&view_type=kanban&cids=1&menu_id=114"
          # Screenshots
          ''$mainMod, S, exec, grim -g "$(slurp)" "$HOME/Pictures/Screenshots/$(date '+%y%m%d_%H-%M-%S').png"''
          ''$mainMod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''
          # Move focus with mainMod + arrow keys
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"
          # Move windows with mainMod + shift + arrow keys
          "$mainMod SHIFT, left, movewindow, l"
          "$mainMod SHIFT, right, movewindow, r"
          "$mainMod SHIFT, up, movewindow, u"
          "$mainMod SHIFT, down, movewindow, d"
          # Special workspace (scratchpad)
          "$mainMod, A, togglespecialworkspace, magic"
          "$mainMod SHIFT, A, movetoworkspacesilent, special:magic"
          # Hyprpicker color picker
          "$mainMod, mouse:274, exec, hyprpicker -a"
          # Workspaces created/switched/moved on the active monitor
          # Switching workspaces
          "$mainMod CTRL, left, focusworkspaceoncurrentmonitor,e-1"
          "$mainMod CTRL, right, focusworkspaceoncurrentmonitor,e+1"
          # Moving windows to workspaces
          "$mainMod SHIFT, mouse_down,movetoworkspace,e-1"
          "$mainMod SHIFT, mouse_up,movetoworkspace,e+1"
        ]
        ++ (
          # workspaces
          # binds $mainMod + [shift +] {1..9} to [move to] workspace {1..9}
          builtins.concatLists (builtins.genList
            (
              x:
              let
                ws =
                  let
                    c = (x + 1) / 10;
                  in
                  builtins.toString (x + 1 - (c * 10));
              in
              [
                "$mainMod, ${ws}, workspace, ${toString (x + 1)}"
                "$mainMod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
              ]
            )
            10)
        );
    };
  };
  # Lockscreen
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 60;
        ignore_empty_input = true;
      };
      background = [
        {
          monitor = "";
          path = "/etc/nixos/modules/wallpapers/lex.png";
          color = "rgba(25, 20, 20, 1.0)";
          blur_passes = 2; # 0 disables blurring
          blur_size = 2;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];
      input-field = [
        {
          monitor = "DP-4";
          size = "200, 50";
          outline_thickness = 3;
          dots_size = 0.33;
          dots_spacing = 0.15;
          dots_center = false;
          dots_rounding = -1;
          outer_color = "rgb(151515)";
          inner_color = "rgb(200, 200, 200)";
          font_color = "rgb(10, 10, 10)";
          fade_on_empty = true;
          fade_timeout = 1000;
          placeholder_text = "<i>Input Password...</i>";
          hide_input = false;
          rounding = -1;
          check_color = "rgb(204, 136, 34)";
          fail_color = "rgb(204, 34, 34)";
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          fail_transition = 300;
          capslock_color = -1;
          numlock_color = -1;
          bothlock_color = -1;
          invert_numlock = false;
          swap_font_color = false;
        }
      ];
    };
  };
  # Idle management
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "hyprlock";
        unlock_cmd = "echo 'unlock!'";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          timeout = 150; # 2.5min.
        }
        {
          timeout = 900; # 15min.
          on-timeout = "loginctl lock-session";
          on-resume = "echo 'service resumed'";
        }
        {
          timeout = 980; # 16min.
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 86400; # 24h.
          on-timeout = "systemctl suspend";
          on-resume = "echo 'service resumed'";
        }
      ];
    };
  };
}

{ config, pkgs, ... }:
  {
    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = ''
        exec-once = ~/Code/dotfiles/scripts/sleep.sh
        exec-once = waybar
        exec-once = mako
        exec-once = swww query || swww init
        exec-once = ~/Code/dotfiles/scripts/wallpaper.sh ~/Pictures/Wallpapers
        source= ~/.cache/wal/colors-hyprland.conf
      '';
      settings = {
        windowrulev2 = [
          "opacity 0.9 0.9,class:^(Code)$"
          "opacity 0.95 0.95,class:^(google-chrome)$"
          "opacity 0.9 0.9,class:^(chrome-)"
          
          ];
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
        monitor = [
          "DP-2,2560x1080@60,0x0,1"
          "DP-1,2560x1080@60,0x1080,1"
        ];
        input = {
          numlock_by_default = "true";
          follow_mouse = "1";
          sensitivity = "-.7";
          kb_model = "pc104";
          kb_layout = "us";
        };
        general =  {
          border_size = "2";
          gaps_in = "5";
          gaps_out = "20";
          layout = "master";
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
        };
        decoration = {
          rounding = "10";
          blur = {
            enabled = "true";
            size = "3";
            passes = "1";
            new_optimizations = "true";
          };
        drop_shadow = "yes";
        shadow_range = "4";
        shadow_render_power = "3";
        "col.shadow" = "rgba(1a1a1aee)";
        };
        dwindle = {
          pseudotile = "yes";
          preserve_split = "yes";
        };
        master = {
          new_is_master = "true";
        };
        gestures = {
          workspace_swipe = "off";
        };
        misc = {
          mouse_move_enables_dpms = "true";
          key_press_enables_dpms = "true";
          force_default_wallpaper = "0";
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
            "$mainMod, ESCAPE, exec, wlogout"
            "$mainMod, Q, exec, kitty"
            "$mainMod, C, killactive"
            "$mainMod, E, exec, nautilus"
            "$mainMod, V, togglefloating"
            "$mainMod, Tab, exec, rofi -show drun -show-icons"
            "$mainMod, F, fullscreen"
            "$mainMod SHIFT, F, fakefullscreen"
            # Number keys (0, -, +)
            "$mainMod, KP_Insert, exec, google-chrome-stable --app=https://chat.openai.com"
            "$mainMod, KP_Add, exec, hyprctl dispatch exec [floating] gnome-calculator"
            "$mainMod, KP_Enter, exec, google-chrome-stable --app=https://essay.app/home/"
            "$mainMod, KP_Subtract, exec, google-chrome-stable --app=https://recorder.google.com/"
            # Number keys (1, 2, 3)
            "$mainMod, KP_End, exec, google-chrome-stable --app=https://mail.google.com"
            "$mainMod, KP_Down, exec, google-chrome-stable --app=https://messages.google.com/web/u/0/conversations"
            "$mainMod, KP_Next, exec, google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r"
            # Number keys (4, 5, 6)
            "$mainMod, KP_Left, exec, google-chrome-stable --app=https://app.asana.com/home"
            "$mainMod, KP_Begin, exec, google-chrome-stable --app=https://app.reclaim.ai/planner?taskSort=schedule"
            "$mainMod, KP_Right, exec, google-chrome-stable --app=https://tmvsocial.harvestapp.com/projects?filter=active"
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
          ]
          ++ (
            # workspaces
            # binds $mainMod + [shift +] {1..9} to [move to] workspace {1..9}
            builtins.concatLists (builtins.genList (
                x: let
                  ws = let
                    c = (x + 1) / 10;
                  in
                    builtins.toString (x + 1 - (c * 10));
                in [
                  "$mainMod, ${ws}, workspace, ${toString (x + 1)}"
                  "$mainMod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
                ]
              )
              10)
          );
      };
    };
  }
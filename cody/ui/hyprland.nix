{ config, pkgs, lib, inputs, hardwareConfig, stylix, ... }:

{
  home.packages = with pkgs; [
    hyprnome
  ];

  imports = [
    ./hyprland/keybinds.nix
  ];

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
      # Workspace and monitor set in flake.nix
      workspace = hardwareConfig.workspace;
      monitor = hardwareConfig.monitor;
      exec-once = [
        "swaync"
        "dbus-update-activation-environment --systemd --all"
        "wl-clipboard-history -t"
        "wl-paste --watch cliphist store"
        ''rm "$HOME/.cache/cliphist/db"'' # Clear clipboard history on startup
      ];
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
        gaps_out = "20";
        layout = "master";
        "col.active_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base0C}ff) rgba(${config.lib.stylix.colors.base0D}ff) rgba(${config.lib.stylix.colors.base0B}ff) rgba(${config.lib.stylix.colors.base0E}ff) 45deg";
        "col.inactive_border" = lib.mkForce "rgba(${config.lib.stylix.colors.base00}cc) rgba(${config.lib.stylix.colors.base01}cc) 45deg";
      };
      cursor.hide_on_key_press = true;
      decoration = {
        rounding = "10";
        active_opacity = "0.9";
        inactive_opacity = "0.8";
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
        disable_hyprland_logo = "true";
      };
      # Window rules
      windowrule = "noblur,^(kitty)$";
    };
  };
  # Lockscreen
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 900; # 15mins.
        ignore_empty_input = true;
      };
      background = lib.mkForce [
        {
          monitor = "";
          path = "screenshot";
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
      input-field = lib.mkForce [
        {
          monitor = "DP-1";
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
          timeout = 900; # 15min.
          on-timeout = "loginctl lock-session";
          on-resume = "echo 'service resumed'";
        }
        {
          timeout = 1800; # 30min.
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

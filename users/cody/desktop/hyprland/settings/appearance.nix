{
  config,
  lib,
  ...
}:

{
  wayland.windowManager.hyprland.settings = {
    config = {
      ecosystem = {
        no_update_news = true;
        no_donation_nag = true;
      };

      animations.enabled = true;

      input = {
        numlock_by_default = true;
        follow_mouse = 1;
        sensitivity = -0.7;
        force_no_accel = 0;
        kb_layout = "us";
      };

      debug = {
        full_cm_proto = true;
      };

      render = {
        direct_scanout = 2;
      };

      general = {
        allow_tearing = true;
        border_size = 2;
        gaps_in = 2;
        gaps_out = 2;
        layout = "master";
        "col.active_border" = lib.mkForce {
          colors = [
            "rgba(${config.lib.stylix.colors.base0C}aa)"
            "rgba(${config.lib.stylix.colors.base0D}aa)"
            "rgba(${config.lib.stylix.colors.base0B}aa)"
            "rgba(${config.lib.stylix.colors.base0E}aa)"
          ];
          angle = 45;
        };
        "col.inactive_border" = lib.mkForce {
          colors = [
            "rgba(${config.lib.stylix.colors.base00}99)"
            "rgba(${config.lib.stylix.colors.base01}99)"
          ];
          angle = 45;
        };
      };

      cursor = {
        hide_on_key_press = true;
      };

      decoration = {
        rounding = 10;
        active_opacity = 0.95;
        inactive_opacity = 0.75;
        blur = {
          enabled = true;
          size = 10;
          passes = 3;
          new_optimizations = true;
          ignore_opacity = true;
          noise = 0;
          brightness = 0.60;
        };
        shadow = {
          enabled = true;
          render_power = 3;
          range = 4;
          color = lib.mkForce "rgba(1a1a1aee)";
        };
      };

      dwindle = {
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        force_default_wallpaper = 0;
        disable_hyprland_logo = lib.mkForce true;
        focus_on_activate = true;
      };
    };

    # Custom curves used by the animation entries below
    curve = [
      {
        _args = [
          "easeInExpo"
          {
            type = "bezier";
            points = [
              [ 0.7 0 ]
              [ 0.84 0 ]
            ];
          }
        ];
      }
      {
        _args = [
          "easeOutExpo"
          {
            type = "bezier";
            points = [
              [ 0.16 1 ]
              [ 0.3 1 ]
            ];
          }
        ];
      }
    ];

    animation = [
      {
        leaf = "windows";
        enabled = true;
        speed = 1;
        bezier = "easeInExpo";
        style = "slide";
      }
      {
        leaf = "windowsIn";
        enabled = true;
        speed = 1;
        bezier = "easeInExpo";
        style = "slide 80%";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 1;
        bezier = "easeOutExpo";
        style = "slide 80%";
      }
      {
        leaf = "border";
        enabled = true;
        speed = 10;
        bezier = "default";
      }
      {
        leaf = "borderangle";
        enabled = true;
        speed = 8;
        bezier = "default";
      }
      {
        leaf = "fade";
        enabled = true;
        speed = 2;
        bezier = "default";
      }
      {
        leaf = "workspaces";
        enabled = false;
      }
    ];
  };
}

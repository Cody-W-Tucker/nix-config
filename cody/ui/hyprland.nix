{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./hyprland/settings.nix
    ./hyprland/autostart.nix
  ];

  home.packages = with pkgs; [
    hyprnome
  ];

  # Bring in env session variables from ../ui.nix
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

  services = {
    wayland.windowManager.hyprland = {
      enable = true;
      package = null; # null to use NixOS module
      portalPackage = null; # null to use NixOS module
      systemd.enable = false; # Since using UWSM, disable systemd
      xwayland.enable = true;
    };

    # Use the Hyprland Polkit
    hyprpolkitagent.enable = true;
    gnome-keyring = {
      enable = true;
      components = [
        "secrets"
        "ssh"
      ];
    };

    # Idle management
    hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "hyprlock";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        listener = [
          {
            timeout = 900; # 15min.
            on-timeout = "hyprlock";
          }
          {
            timeout = 1800; # 30min.
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 3600; # 1hr.
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };
  };

  # Lock screen
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 300; # 5mins.
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
          capslock_color = -1;
          numlock_color = -1;
          bothlock_color = -1;
          invert_numlock = false;
          swap_font_color = false;
        }
      ];
    };
  };
}

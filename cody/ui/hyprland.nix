{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    hyprnome
  ];

  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" "ssh" ];
  };

  imports = [
    ./hyprland/settings.nix
    ./hyprland/autostart.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
  };
  # Lockscreen: blurs after 15mins with another 15mins grace, then turns monitor off and locks
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

{ config, pkgs, lib, ... }:

# Create a reusable function to create each bar
# Bottom monitor bar focus on work
# Top monitor bar gives more information
# Want varibles to be more clear, "DP-1" is bottom monitor, "top" places the bar at the top of the screen
let
  createBar = waybarConfig: output: position: waybarConfig // { output = output; position = position; };
  # Productivity Bar Config: This is the main bar for the main monitor.
  productivityBarConfig = {
    layer = "top";
    spacing = 4;
    modules-center = [ "clock" "custom/timer" ];
    modules-left = [ "hyprland/workspaces" ];
    modules-right = [
      "group/group-power"
    ];
    "hyprland/workspaces" = {
      on-click = "activate";
      format = "{}";
    };
    "custom/timer" = {
      exec = "waybar-timer updateandprint";
      exec-on-event = true;
      return-type = "json";
      interval = 5;
      signal = 4;
      format = "{icon} {0}";
      format-icons = {
        standby = ""; # Font Awesome pause icon
        running = ""; # Font Awesome hourglass icon
        paused = ""; # Font Awesome stop icon
      };
      on-click = "waybar-timer new 25 'notify-send -u critical \"Timer expired.\"'";
      on-click-middle = "waybar-timer cancel";
      on-click-right = "waybar-timer togglepause";
      on-scroll-up = "waybar-timer increase 300 || waybar-timer new 5 'notify-send -u critical \"Timer expired.\"'";
      on-scroll-down = "waybar-timer increase -300 || 'notify-send -u critical \"Timer expired.\"'";
    };
    clock = {
      format = "{:%m/%d/%Y - %I:%M %p}";
      tooltip = true;
      on-click-right = "exec google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
      calendar = {
        mode = "year";
        mode-mon-col = 3;
        weeks-pos = "left";
        on-scroll = 1;
        format = {
          months = "<span color='#ffead3'><b>{}</b></span>";
          days = "<span color='#ecc6d9'><b>{}</b></span>";
          weeks = "<span color='#99ffdd'><b>W{}</b></span>";
          weekdays = "<span color='#ffcc66'><b>{}</b></span>";
          today = "<span color='#ff6699'><b><u>{}</u></b></span>";
        };
      };
    };
    "hyprland/window" = {
      max-length = 200;
      separate-outputs = true;
    };
    "group/group-power" = {
      orientation = "inherit";
      drawer = {
        transition-duration = 500;
        children-class = "not-power";
        transition-left-to-right = false;
      };
      modules = [
        "custom/power"
        "custom/quit"
        "custom/lock"
        "custom/reboot"
      ];
    };
    "custom/quit" = {
      format = "󰗼";
      tooltip = true;
      tooltip-format = "Quit";
      on-click = "hyprctl dispatch exit";
    };
    "custom/lock" = {
      format = "󰍁";
      tooltip-format = "Lock";
      tooltip = true;
      on-click = "hyprlock";
    };
    "custom/reboot" = {
      format = "󰜉";
      tooltip-format = "Reboot";
      tooltip = true;
      on-click = "reboot";
    };
    "custom/power" = {
      format = "";
      tooltip-format = "Shutdown";
      tooltip = false;
      on-click = "shutdown now";
    };
  };
  # Secondary Config: 
  secondaryBarConfig = {
    layer = "top";
    spacing = 4;
    modules-center = [
      "custom/media"
      "pulseaudio"
      "privacy"
    ];
    modules-left = [ "hyprland/workspaces" "tray" ];
    modules-right = [
      "custom/notification"
      "cpu"
      "memory"
      "temperature"
    ];
    "hyprland/workspaces" = {
      on-click = "activate";
      format = "{}";
    };
    "custom/media" = {
      format = "{}";
      escape = true;
      interval = 5;
      return-type = "json";
      max-length = 40;
      on-click = "playerctl play-pause";
      on-click-right = "playerctl stop";
      smooth-scrolling-threshold = 1;
      on-scroll-up = "playerctl next";
      on-scroll-down = "playerctl previous";
      exec = "media-player";
    };
    cpu = {
      interval = 5;
      format = "{usage:2}% ";
      tooltip = true;
    };
    memory = {
      interval = 5;
      format = "{}% ";
      tooltip = true;
    };
    temperature = {
      critical-threshold = 80;
      # thermal-zone = 2;
      hwmon-path = "/sys/devices/platform/coretemp.0/hwmon/hwmon2/temp1_input";
      format = "{temperatureC}°C ";
      tooltip = false;
    };
    tray = {
      icon-size = 21;
      spacing = 10;
    };
    privacy = {
      icon-spacing = 4;
      icon-size = 18;
      transition-duration = 250;
      modules = [
        {
          type = "screenshare";
          tooltip = true;
          tooltip-icon-size = 24;
        }
        {
          type = "audio-in";
          tooltip = true;
          tooltip-icon-size = 24;
        }
      ];
    };
    pulseaudio = {
      format = "{volume}% {icon} {format_source}";
      format-bluetooth = "{volume}% {icon} {format_source}";
      format-bluetooth-muted = " {icon} {format_source}";
      format-muted = " {format_source}";
      format-source = "{volume}% ";
      format-source-muted = "";
      ss = {
        headphone = "";
        hands-free = "";
        headset = "";
        phone = "";
        portable = "";
        car = "";
        default = [ "" "" "" ];
      };
      on-click = "exec bluetoothSwitch";
      on-click-right = "pavucontrol";
    };
    "hyprland/window" = {
      max-length = 200;
      separate-outputs = true;
    };
    "custom/notification" = {
      tooltip = false;
      format = "{icon} {}";
      format-icons = {
        notification = "<span foreground='#${config.lib.stylix.colors.base0A}'><sup></sup></span>";
        none = "";
        dnd-notification = "<span foreground='#${config.lib.stylix.colors.base0A}'><sup></sup></span>";
        dnd-none = "";
        inhibited-notification = "<span foreground='#${config.lib.stylix.colors.base0A}'><sup></sup></span>";
        inhibited-none = "";
        dnd-inhibited-notification = "<span foreground='#${config.lib.stylix.colors.base0A}'><sup></sup></span>";
        dnd-inhibited-none = "";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "sleep 0.1 && swaync-client -t -sw";
      on-click-right = "swaync-client -C";
      on-click-middle = "sleep 0.1 && swaync-client -d -sw";
      escape = true;
    };
  };

in
{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "hyprland-session.target";
    };
    settings = {
      # Duplicate the bars for each monitor
      monitor1 = createBar productivityBarConfig "DP-1" "top";
      monitor2 = createBar secondaryBarConfig "DP-2" "bottom";
    };
    style = lib.mkForce ''
      * {
        font-family: JetBrainsMono, Roboto, Helvetica, Arial, sans-serif;
        font-size: 15px;
      }

      window#waybar {
        background-color: #${config.lib.stylix.colors.base01};
        color: #${config.lib.stylix.colors.base05};
        border-bottom: 1px solid #${config.lib.stylix.colors.base00};
      }

      #cpu,
      #memory,
      #pulseaudio,
      #pulseaudio.muted,
      #temperature,
      #clock,
      #tray,
      #custom-notification,
      #custom-media,
      #custom-timer,
      #custom-power,
      #custom-quit,
      #custom-lock,
      #custom-reboot,
      #workspaces {
        padding: 5px 10px;
        box-shadow: 0px 2px 5px rgba(0, 0, 0, 0.15);
        background-color: #${config.lib.stylix.colors.base00};
        color: #${config.lib.stylix.colors.base05};
      }

      #workspaces button {
        padding: 0 10px;
        margin: 0 2px;
      }

      #workspaces button:hover {
        background: #${config.lib.stylix.colors.base0D};
      }

      #workspaces button.urgent {
        background-color: #${config.lib.stylix.colors.base09};
      }

      /* If workspaces is the leftmost module, omit left margin */
      .modules-left > widget:first-child > #workspaces {
        margin-left: 0;
      }

      /* If workspaces is the rightmost module, omit right margin */
      .modules-right > widget:last-child > #workspaces {
        margin-right: 0;
      }

      @keyframes blink {
        to {
          background-color: #${config.lib.stylix.colors.base00};
          color: #000000;
        }
      }

      label:focus {
        background-color: #${config.lib.stylix.colors.base00};
      }

      #privacy {
        padding: 0;
      }

      #privacy-item {
        padding: 0 5px;
        color: white;
      }

      #privacy-item.screenshare {
        background-color: #cf5700;
      }

      #privacy-item.audio-in {
        background-color: #1ca000;
      }

      #privacy-item.audio-out {
        background-color: #0069d4;
      }

      #custom-power,
      #custom-quit,
      #custom-lock,
      #custom-reboot {
        font-size: large;
      }
    '';
  };
}

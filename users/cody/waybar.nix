{ config, pkgs, lib, ... }:

# Create a reusable function to create a bar (since I want to duplicate the bar for each monitor)
let
  createBar = waybarConfig: output: position: waybarConfig // { output = output; position = position; };
  waybarConfig = {
    layer = "top";
    reload_style_on_change = true;
    spacing = 4;
    modules-center = [ "clock" "custom/notification" ];
    modules-left = [ "hyprland/workspaces" ];
    modules-right = [
      "tray"
      "pulseaudio"
      "cpu"
      "memory"
      "temperature"
      "group/group-power"
    ];
    "hyprland/workspaces" = {
      on-click = "activate";
      format = "{}";
      on-scroll-up = "hyprctl dispatch workspace e+1";
      on-scroll-down = "hyprctl dispatch workspace e-1";
    };
    clock = {
      format = "{:%m/%d/%Y - %I:%M %p}";
      on-click-right = "exec google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r";
    };
    cpu = {
      format = "{usage}% ";
      tooltip = false;
    };
    memory = {
      format = "{}% ";
    };
    temperature = {
      critical-threshold = 80;
      # thermal-zone = 2;
      hwmon-path = "/sys/devices/platform/coretemp.0/hwmon/hwmon2/temp1_input";
      format = "{temperatureC}°C ";
    };
    tray = {
      icon-size = 21;
      spacing = 10;
    };
    pulseaudio = {
      format = "{volume}% {icon} {format_source}";
      format-bluetooth = "{volume}% {icon} {format_source}";
      format-bluetooth-muted = " {icon} {format_source}";
      format-muted = " {format_source}";
      format-source = "{volume}% ";
      format-source-muted = "";
      format-icons = {
        headphone = "";
        hands-free = "";
        headset = "";
        phone = "";
        portable = "";
        car = "";
        default = [ "" "" "" ];
      };
      on-click = "pavucontrol";
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
    "custom/notification" = {
      tooltip = false;
      format = "{} {icon}";
      "format-icons" = {
        notification = "󱅫";
        none = "";
        "dnd-notification" = " ";
        "dnd-none" = "󰂛";
        "inhibited-notification" = " ";
        "inhibited-none" = "";
        "dnd-inhibited-notification" = " ";
        "dnd-inhibited-none" = " ";
      };
      "return-type" = "json";
      "exec-if" = "which swaync-client";
      exec = "swaync-client -swb";
      "on-click" = "sleep 0.1 && swaync-client -t -sw";
      "on-click-right" = "sleep 0.1 && swaync-client -d -sw";
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
      monitor1 = createBar waybarConfig "DP-1" "top";
      monitor2 = createBar waybarConfig "DP-2" "bottom";
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

      #workspaces {
        padding: 0 15px;
        background-color: #${config.lib.stylix.colors.base00};
        color: #${config.lib.stylix.colors.base05};
      }

      #workspaces button {
        padding: 0 10px;
        margin: 0 2px;
        background-color: #${config.lib.stylix.colors.base00};
        color: #${config.lib.stylix.colors.base05};
      }

      #workspaces button:hover {
        background: #${config.lib.stylix.colors.base0D};
      }

      #workspaces button.urgent {
        background-color: #${config.lib.stylix.colors.base09};
      }

      #clock,
      #custom-notification,
      #battery,
      #bluetooth,
      #cpu,
      #memory,
      #disk,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #wireplumber,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #scratchpad,
      #mpd,
      #custom-power,
      #custom-quit,
      #custom-lock,
      #custom-reboot,
      #workspaces {
        padding: 0 10px;
        color: #${config.lib.stylix.colors.base05};
        border: 1px solid #${config.lib.stylix.colors.base02};
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

      #cpu,
      #memory,
      #disk,
      #pulseaudio,
      #pulseaudio.muted,
      #wireplumber,
      #wireplumber.muted,
      #temperature,
      #clock,
      #workspaces,
      #bluetooth {
        padding: 5px 10px;
        box-shadow: 0px 2px 5px rgba(0, 0, 0, 0.15);
        background-color: #${config.lib.stylix.colors.base00};
        color: #${config.lib.stylix.colors.base05};
      }

      #idle_inhibitor {
        background-color: #2d3436;
      }

      #idle_inhibitor.activated {
        background-color: #ecf0f1;
        color: #2d3436;
      }

      #scratchpad {
        background: rgba(0, 0, 0, 0.2);
      }

      #scratchpad.empty {
        background-color: transparent;
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

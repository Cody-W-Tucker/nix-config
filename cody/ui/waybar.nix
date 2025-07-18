{ config, lib, pkgs, inputs, ... }:

# Create a reusable function to create each bar
# Bottom monitor bar focus on work
# Top monitor bar gives more information
let nextmeeting = lib.getExe inputs.nextmeeting.packages.${pkgs.system}.default;
in
let
  createBar = waybarConfig: output: position: waybarConfig // { output = output; position = position; };
  # Productivity Bar Config: This is the main bar for the main monitor.
  productivityBarConfig = {
    layer = "top";
    spacing = 4;
    modules-left = [
      "hyprland/workspaces"
      "tray"
      "hyprland/window"
    ];
    modules-center = [
      "custom/notification"
      "clock"
      "privacy"
      "pulseaudio"
    ];
    modules-right = [
      "custom/media"
      "custom/agenda"
      "custom/weather"
      "group/group-power"
    ];
    "hyprland/workspaces" = {
      on-click = "activate";
      show-special = true;
      format = "{icon} {windows}";
      window-rewrite = {
        "Zen Browser" = "🞋";
        "spotify" = "";
        "code" = "󰨞";
        "kitty" = "";
        "obsidian" = "";
        "class<Zen Browser> title<.*Github.*>" = "";
        "class<Zen Browser> title<.*Reddit.*>" = "";
        "class<Zen Browser> title<.*Facebook.*>" = "";
        "class<Zen Browser> title<.*Gmail.*>" = "";
        "class<Zen Browser> title<.*Calendar.*>" = "";
      };
      window-rewrite-default = "󰏗";
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
      on-click = "uwsm-app -- bluetoothSwitch";
      on-click-right = "uwsm-app -- pavucontrol";
    };
    temperature = {
      hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
      input-filename = "temp2_input";
      format = "{temperatureC}°C ";
      format-critical = "{temperatureC}°C ";
      tooltip-format = "{temperatureF}°F";
      critical-threshold = 85;
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
    tray = {
      icon-size = 21;
      spacing = 10;
    };
    "custom/agenda" = {
      exec = nextmeeting + " --skip-all-day-meeting --waybar --gcalcli-cmdline \"gcalcli --nocolor agenda today --nodeclined --details=end --details=url --tsv\"";
      on-click = nextmeeting + "--open-meet-url";
      on-click-right = "xdg-open https://app.reclaim.ai/planner";
      format = "󰃶 {}";
      return-type = "json";
      interval = 59;
      tooltip = true;
    };
    "custom/weather" = {
      exec = "uwsm-app -- get-weather Kearney+Nebraska";
      return-type = "json";
      format = "{}";
      tooltip = true;
      interval = 3600;
    };
    "custom/goal" = {
      format = "🞋 {}";
      exec = "waybar-goal";
      return-type = "json";
      interval = 10;
      on-click = "waybar-goal click";
      on-scroll-up = "waybar-goal scroll-up";
      on-scroll-down = "waybar-goal scroll-down";
    };
    clock = {
      format = "{:%a (%d) - %I:%M %p}";
      tooltip = true;
      on-click-right = "xdg-open https://calendar.google.com/calendar/u/0/r";
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
      format = "❯ {title}";
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
      on-click = "hyprctl dispatch exec, uwsm stop";
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
      on-click = "systemctl reboot";
    };
    "custom/power" = {
      format = "";
      tooltip-format = "Shutdown";
      tooltip = false;
      on-click = "shutdown now";
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
      on-click = "uwsm-app -- sleep 0.1 && swaync-client -t -sw";
      on-click-right = "swaync-client -C";
      on-click-middle = "sleep 0.1 && swaync-client -d -sw";
      escape = true;
    };
    disk = {
      format = "{percentage_free}% ";
    };
    cpu = {
      interval = 5;
      format = "{usage:2}% ";
      tooltip = true;
    };
    memory = {
      interval = 5;
      format = "{}% ";
      tooltip = true;
    };
  };
  # Secondary Config: 
  secondaryBarConfig = {
    layer = "top";
    spacing = 4;
    modules-center = [
      "clock"
    ];
    modules-left = [
      "hyprland/workspaces"
      # "tray" Shouldn't have two trays, but I like it
      "hyprland/window"
    ];
    modules-right = [ ];
    clock = {
      format = "{:%a (%d) - %I:%M %p}";
      tooltip = true;
      on-click-right = "xdg-open https://calendar.google.com/calendar/u/0/r";
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
    "hyprland/workspaces" = {
      on-click = "activate";
      show-special = true;
      format = "{icon} {windows}";
      window-rewrite = {
        "Zen Browser" = "🞋";
        "spotify" = "";
        "code" = "󰨞";
        "kitty" = "";
        "obsidian" = "";
        "class<Zen Browser> title<.*Github.*>" = "";
        "class<Zen Browser> title<.*Reddit.*>" = "";
        "class<Zen Browser> title<.*Facebook.*>" = "";
        "class<Zen Browser> title<.*Gmail.*>" = "";
        "class<Zen Browser> title<.*Calendar.*>" = "";
      };
      window-rewrite-default = "󰏗";
    };
    "hyprland/window" = {
      format = "❯ {title}";
      separate-outputs = true;
    };
  };

in
{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
    settings = {
      # Duplicate the bars for each monitor
      monitor1 = createBar productivityBarConfig "DP-1" "top";
      monitor2 = createBar secondaryBarConfig "HDMI-A-3" "top";
      monitor3 = createBar secondaryBarConfig "DP-3" "top";
    };
    style = lib.mkForce ''
      * {
        font-family: JetBrainsMono, Roboto, Helvetica, Arial, sans-serif;
        font-size: 15px;
      }

      window#waybar {
        background-color: #${config.lib.stylix.colors.base01};
      }

      .module {
        padding: 5px 10px;
        box-shadow: 0px 2px 5px rgba(0, 0, 0, 0.15);
        background-color: #${config.lib.stylix.colors.base01};
        border: 2px solid #${config.lib.stylix.colors.base02};
        color: #${config.lib.stylix.colors.base05};
      }

      .module:hover {
        border-color: #${config.lib.stylix.colors.base03};
      }

      #workspaces button {
        padding: 0 10px;
        margin: 0 2px;
        color: #${config.lib.stylix.colors.base04};
      }

      #workspaces button.visible {
        color: #${config.lib.stylix.colors.base05};
      }

      #workspaces button.active {
        color: #${config.lib.stylix.colors.base05};
      }

      #workspaces button:hover {
        background: #${config.lib.stylix.colors.base02};
      }

      #workspaces button.urgent {
        background-color: #${config.lib.stylix.colors.base09};
      }

      /* If leftmost module, omit left margin */
      .modules-left > widget:first-child > #workspaces, #custom-power {
        margin-left: 0;
      }

      /* If rightmost module, omit right margin */
      .modules-right > widget:last-child > #workspaces, #custom-power {
        margin-right: 0;
      }

      @keyframes blink {
        to {
          background-color: #${config.lib.stylix.colors.base00};
          color: #000000;
        }
      }

      label:focus {
        background-color: #${config.lib.stylix.colors.base02};
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

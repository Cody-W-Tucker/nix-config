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
      "custom/agenda"
      "custom/notification"
    ];
    modules-center = [
      "clock"
    ];
    modules-right = [
      "privacy"
      "pulseaudio"
      "custom/media"
      "group/hardware"
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
      format = "{volume}% {icon}";
      format-bluetooth = "{volume}% {icon}";
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
      on-click-right = "xdg-open https://calendar.google.com/calendar/u/0/r";
      format = "󰃶 {}";
      return-type = "json";
      interval = 59;
      tooltip = true;
    };
    clock = {
      format = "{:%d - %I:%M}";
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
    "group/hardware" = {
      orientation = "horizontal";
      drawer = {
        transition-duration = 500;
        transition-left-to-right = true;
      };
      modules = [
        "cpu"
        "temperature"
        "memory"
        "disk"
      ];
    };
    cpu = {
      format = "{icon0} {icon1} {icon2} {icon3} {icon4} {icon5} {icon6} {icon7}";
      format-icons = [
        "▁"
        "▂"
        "▃"
        "▄"
        "▅"
        "▆"
        "▇"
        "█"
      ];
    };
    memory = {
      interval = 30;
      format = "{used:0.1f}G/{total:0.1f}G ";
    };
    disk = {
      format = "{percentage_free}% ";
    };
    temperature = {
      format = "{temperatureC}°C ";
      format-critical = "{temperatureC}°C ";
      tooltip-format = "{temperatureF}°F";
      critical-threshold = 85;
      hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
      input-filename = "temp1_input";
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
    ];
    modules-right = [
      "tray" # Shouldn't have two trays, but I like it
    ];
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
        background-color: rgba(30, 30, 40, 0.6); /* semi-transparent dark */
        border-radius: 18px;
        box-shadow: 0 4px 24px 0 rgba(0,0,0,0.25);
        margin: 8px 16px;
        border: 2px solid #${config.lib.stylix.colors.base02};
        /* Optional: blur effect for extra modern look (if supported) */
        backdrop-filter: blur(12px);
      }

      .module {
        padding: 6px 18px;
        margin: 0 6px;
        border-radius: 999px; /* pill shape */
        background-color: rgba(40, 40, 60, 0.7);
        border: none;
        color: #${config.lib.stylix.colors.base05};
        box-shadow: 0 2px 8px rgba(0,0,0,0.10);
        transition: background 0.2s, color 0.2s, box-shadow 0.2s;
      }

      /* Alternate module colors for differentiation */
      .modules-left > .module:nth-child(odd),
      .modules-center > .module:nth-child(odd),
      .modules-right > .module:nth-child(odd) {
        background-color: rgba(60, 60, 100, 0.7);
      }
      .modules-left > .module:nth-child(even),
      .modules-center > .module:nth-child(even),
      .modules-right > .module:nth-child(even) {
        background-color: rgba(30, 60, 90, 0.7);
      }

      .module:hover {
        background-color: #${config.lib.stylix.colors.base0A}cc;
        color: #fff;
        box-shadow: 0 4px 16px rgba(0,0,0,0.18);
      }

      #workspaces button {
        padding: 0 14px;
        margin: 0 4px;
        border-radius: 999px;
        background: rgba(80, 80, 120, 0.5);
        color: #${config.lib.stylix.colors.base04};
        border: none;
        transition: background 0.2s, color 0.2s;
      }

      #workspaces button.visible {
        color: #${config.lib.stylix.colors.base05};
        background: #${config.lib.stylix.colors.base0B}cc;
      }

      #workspaces button.active {
        color: #fff;
        background: #${config.lib.stylix.colors.base0D}cc;
      }

      #workspaces button:hover {
        background: #${config.lib.stylix.colors.base0A}cc;
        color: #fff;
      }

      #workspaces button.urgent {
        background-color: #${config.lib.stylix.colors.base09}cc;
        color: #fff;
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
        padding: 0 8px;
        border-radius: 999px;
        color: white;
        margin: 0 2px;
      }

      #privacy-item.screenshare {
        background-color: #cf5700cc;
      }

      #privacy-item.audio-in {
        background-color: #1ca000cc;
      }

      #privacy-item.audio-out {
        background-color: #0069d4cc;
      }
    '';
  };
}

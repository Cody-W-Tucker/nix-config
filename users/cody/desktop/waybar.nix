{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  nextmeeting = lib.getExe inputs.nextmeeting.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesDashboardSessionToken =
    config.services.hermes-agent.environment.HERMES_DASHBOARD_SESSION_TOKEN;
  hermesVoicePython = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.websockets ]);
  hermesVoice = pkgs.writeShellApplication {
    name = "hermes-waybar-voice";
    runtimeInputs = [ pkgs.mpv ];
    text = ''
      export HERMES_BASE_URL="http://127.0.0.1:8642"
      export HERMES_DASHBOARD_SESSION_TOKEN="${hermesDashboardSessionToken}"
      exec ${hermesVoicePython}/bin/python ${./hermes-waybar-voice.py} "$@"
    '';
  };
  hermesVoiceCmd = lib.getExe hermesVoice;
  favorite_apps = {
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
in
{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = [ "graphical-session.target" ];
    };
    settings = [
      {
        position = "top";
        layer = "top";
        spacing = 4;
        modules-left = [
          "group/workspaces"
          "custom/agenda"
        ];
        modules-center = [
          "custom/notification"
          "clock"
          "custom/weather"
        ];
        modules-right = [
          "privacy"
          "custom/hermes-voice"
          "mpris"
          "pulseaudio"
          "group/hardware"
        ];
        "hyprland/workspaces" = {
          on-click = "activate";
          show-special = true;
          format = "{icon} {windows}";
          window-rewrite = favorite_apps;
          window-rewrite-default = "󰏗";
        };
        "group/workspaces" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = true;
          };
          modules = [
            "hyprland/workspaces"
            "tray"
          ];
        };
        pulseaudio = {
          format = "{volume}% {icon}";
          format-bluetooth = "{volume}% {icon}";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
              ""
            ];
          };
          on-click-right = "pavucontrol";
        };
        mpris = {
          format = "{player_icon} {title}";
          title-len = 50;
          format-paused = "{status_icon} {title}";
          player-icons = {
            default = "";
          };
          status-icons = {
            paused = "";
          };
          on-click-right = "playerctl stop";
          smooth-scrolling-threshold = 1;
          on-scroll-up = "playerctl next";
          on-scroll-down = "playerctl previous";
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
        "custom/hermes-voice" = {
          exec = "${hermesVoiceCmd} status";
          on-click = "${hermesVoiceCmd} toggle";
          on-click-right = "${hermesVoiceCmd} reset";
          on-click-middle = "${hermesVoiceCmd} cleanup";
          format = "{}";
          return-type = "json";
          interval = 2;
          tooltip = true;
          escape = true;
        };
        tray = {
          icon-size = 21;
          spacing = 10;
        };
        "custom/agenda" = {
          exec =
            let
              nextmeetingWithClass = pkgs.writeShellScript "nextmeeting-with-class" ''
                OUTPUT=$(${nextmeeting} --skip-all-day-meeting --waybar --gcalcli-cmdline "gcalcli --nocolor agenda today --nodeclined --details=end --details=url --tsv")
                if echo "$OUTPUT" | grep -q '"text": "No meeting'; then
                  echo '{"text":""}'
                else
                  # Extract the text value and prepend calendar icon
                  TEXT=$(echo "$OUTPUT" | sed 's/.*"text": "\([^"]*\)".*/\1/')
                  echo "{\"text\":\"󰃶 $TEXT\"}"
                fi
              '';
            in
            builtins.toString nextmeetingWithClass;
          on-click = nextmeeting + " --open-meet-url";
          on-click-right = "xdg-open https://calendar.google.com/calendar/u/0/r";
          format = "{}";
          return-type = "json";
          interval = 59;
          tooltip = true;
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
        "custom/weather" = {
          format = "{}";
          tooltip = true;
          interval = 3600;
          exec = ''wttrbar --date-format "%m/%d" --location kearney+nebraska --nerd --fahrenheit --mph --observation-time --hide-conditions'';
          return-type = "json";
        };
        "custom/notification" = {
          tooltip = false;
          format = "{icon} {text}";
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
        "group/hardware" = {
          orientation = "horizontal";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = false;
          };
          modules = [
            "temperature"
            "cpu"
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
          on-click = "kitty -e btop";
          format = "{temperatureC}°C ";
          format-critical = "{temperatureC}°C ";
          tooltip-format = "{temperatureF}°F";
          critical-threshold = 85;
          hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
          input-filename = "temp1_input";
        };
      }
    ];
    style = lib.mkForce ''
      * {
        font-family: 'JetBrainsMono Nerd Font', Inter, Roboto, Helvetica, Arial, sans-serif;
        font-size: 14px;
      }

      window#waybar {
        background-color: transparent;
        border: none;
        box-shadow: none;
        margin: 8px 16px;
        border-radius: 18px;
      }

      .module {
        padding: 2px 12px;
        margin: 0 4px;
        border-radius: 16px;
        background-color: #${config.lib.stylix.colors.base00};
        color: #${config.lib.stylix.colors.base05};
        box-shadow: 0 2px 8px 0 #${config.lib.stylix.colors.base00};
        border: 1px solid #${config.lib.stylix.colors.base04};
        text-shadow: 0 1px 2px #${config.lib.stylix.colors.base00};
        transition: box-shadow 0.2s, border 0.2s, background 0.2s, color 0.2s;
      }

      .module:hover, .module:active {
        box-shadow: 0 4px 16px 0 #${config.lib.stylix.colors.base00};
        border: 1px solid #${config.lib.stylix.colors.base04};
        color: #${config.lib.stylix.colors.base04};
      }

      #workspaces {
        background-color: transparent;
        border: none;
        box-shadow: none;
      }

      #workspaces button {
        padding: 0 14px;
        margin: 0 4px;
        border-radius: 12px;
        border: 1px solid transparent;
        background: transparent;
        color: #${config.lib.stylix.colors.base03};
        transition: all 0.3s ease-in-out;
      }
      #workspaces button.visible {
        color: #${config.lib.stylix.colors.base04};
      }
      #workspaces button.active {
        color: #${config.lib.stylix.colors.base05};
        border: 1px solid #${config.lib.stylix.colors.base04};
      }
      #workspaces button:hover {
        background-color: #${config.lib.stylix.colors.base01};
        border-color: #${config.lib.stylix.colors.base0E};
        color: #${config.lib.stylix.colors.base0E};
      }
      #workspaces button.urgent {
        background-color: #${config.lib.stylix.colors.base08};
        border-color: #${config.lib.stylix.colors.base08};
        color: #${config.lib.stylix.colors.base08};
      }

      #privacy {
        padding: 0;
        background-color: transparent;
        border: none;
        box-shadow: none;
      }

      #privacy-item {
        padding: 0 8px;
        border-radius: 0px;
        color: #${config.lib.stylix.colors.base00};
        margin: 0 2px;
        border: 1px solid #${config.lib.stylix.colors.base00};
        text-shadow: none;
      }

      #privacy-item.screenshare { background-color: #${config.lib.stylix.colors.base0A}; }
      #privacy-item.audio-in { background-color: #${config.lib.stylix.colors.base0B}; }
      #privacy-item.audio-out { background-color: #${config.lib.stylix.colors.base0D}; }

      .modules-left > widget:first-child > #workspaces, #custom-power { margin-left: 0; }
      .modules-right > widget:last-child > #workspaces, #custom-power { margin-right: 0; }

      @keyframes blink {
        to {
          background-color: #${config.lib.stylix.colors.base00};
          color: #000000;
        }
      }

      label:focus {
        background-color: #${config.lib.stylix.colors.base02};
      }
    '';
  };
}

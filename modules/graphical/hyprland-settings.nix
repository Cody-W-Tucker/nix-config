{
  den.aspects.graphical.provides.to-users.homeManager =
    {
      host,
      osConfig,
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (osConfig.codyos.site) domain;
      mainMod = "SUPER";
      browser = "uwsm app -- zen-beta";
      webApp = "chromium --new-window --app";
      terminal = "kitty";

      lua = lib.generators.mkLuaInline;

      exec = cmd: lua "hl.dsp.exec_cmd(${builtins.toJSON cmd})";

      focusOrRun = appClass: cmd: lua ''hl.dsp.exec_cmd("focus-or-run '${appClass}' '${cmd}'")'';

      mkBind = key: action: options: {
        _args = [
          key
          action
        ]
        ++ lib.optionals (options != null) [ options ];
      };

      execBindWith =
        options: key: cmd:
        mkBind key (exec cmd) options;
      execBind = execBindWith null;
      repeatingBind = execBindWith {
        locked = true;
        repeating = true;
      };
      lockedBind = execBindWith { locked = true; };
      actionBind = key: action: mkBind key action null;

      mouseBind = key: action: mkBind key action { mouse = true; };

      screenshotAction = pkgs.writeShellApplication {
        name = "screenshot-to-clipboard";
        runtimeInputs = [
          pkgs.grim
          pkgs.slurp
          pkgs.wl-clipboard
        ];
        text = ''
          grim -g "$(slurp)" - | wl-copy
        '';
      };

      screenshotOcrAction = pkgs.writeShellApplication {
        name = "screenshot-ocr";
        runtimeInputs = [
          pkgs.grim
          pkgs.slurp
          pkgs.wl-clipboard
          pkgs.tesseract4
        ];
        text = ''
          imgname="/tmp/screenshot-ocr-$(date +%Y%m%d%H%M%S).png"
          txtname="/tmp/screenshot-ocr-$(date +%Y%m%d%H%M%S)"
          txtfname="$txtname.txt"
          grim -g "$(slurp)" "$imgname";
          tesseract "$imgname" "$txtname";
          wl-copy -n < "$txtfname"
        '';
      };

      binds = [
        (mouseBind "${mainMod} + mouse:272" (lua "hl.dsp.window.drag()"))
        (mouseBind "${mainMod} + mouse:273" (lua "hl.dsp.window.resize()"))
        (execBind "${mainMod} + Q" terminal)
        (actionBind "${mainMod} + 0" (focusOrRun "zen-beta" browser))
        (execBind "${mainMod} + SHIFT + Return" "[workspace special:ai] ${webApp}=https://grok.com/")
        (execBind "${mainMod} + A" "${webApp}=https://chat.${domain}")
        (execBind "${mainMod} + Tab" "rofi-launcher")
        (execBind "${mainMod} + V" "cliphist list | rofi -dmenu | cliphist decode | wl-copy")
        (execBind "${mainMod} + SHIFT + Tab" "web-search")
        (execBind "${mainMod} + BackSpace" "rofi -show calc -modi calc -no-show-match -no-sort -calc-command 'echo -n \"{result}\" | wl-copy'")
        (execBind "${mainMod} + S" "${lib.getExe screenshotOcrAction}")
        (execBind "${mainMod} + SHIFT + S" "${lib.getExe screenshotAction}")
        (execBind "${mainMod} + mouse:274" "${pkgs.lib.getExe pkgs.hyprpicker} -a")
        (actionBind "${mainMod} + W" (lua "hl.dsp.window.close()"))
        (actionBind "${mainMod} + F" (
          lua ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })''
        ))
        (actionBind "${mainMod} + H" (lua ''hl.dsp.focus({ direction = "l" })''))
        (execBind "${mainMod} + SHIFT + H" "hyprnome --previous --move")
        (actionBind "${mainMod} + L" (lua ''hl.dsp.focus({ direction = "r" })''))
        (execBind "${mainMod} + SHIFT + L" "hyprnome --move")
        (execBind "${mainMod} + mouse_down" "hyprnome --previous")
        (execBind "${mainMod} + mouse_up" "hyprnome")
        (execBind "${mainMod} + SHIFT + mouse_down" "hyprnome --previous --move")
        (execBind "${mainMod} + SHIFT + mouse_up" "hyprnome --move")
        (actionBind "${mainMod} + Return" (lua ''hl.dsp.workspace.toggle_special("ai")''))
        (actionBind "${mainMod} + D" (lua ''hl.dsp.workspace.toggle_special("dev")''))
        (actionBind "${mainMod} + E" (lua ''hl.dsp.workspace.toggle_special("think")''))
        (actionBind "${mainMod} + Y" (lua ''hl.dsp.workspace.toggle_special("media")''))
        (execBind "${mainMod} + P" "pkill -SIGUSR1 waybar")
        (execBind "${mainMod} + Escape" "llama-dictate toggle")
        (execBind "${mainMod} + SHIFT + Escape" "llama-dictate recover")
        (execBind "${mainMod} + CTRL + Escape" "llama-dictate fix")
      ];

      mediaBinds = [
        (repeatingBind "XF86AudioRaiseVolume" "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
        (repeatingBind "XF86AudioLowerVolume" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
        (repeatingBind "XF86AudioMute" "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
        (repeatingBind "XF86AudioMicMute" "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
        (repeatingBind "XF86MonBrightnessUp" "brightnessctl -e4 -n2 set 5%+")
        (repeatingBind "XF86MonBrightnessDown" "brightnessctl -e4 -n2 set 5%-")
        (lockedBind "XF86AudioNext" "playerctl next")
        (lockedBind "XF86AudioPause" "playerctl play-pause")
        (lockedBind "XF86AudioPlay" "playerctl play-pause")
        (lockedBind "XF86AudioPrev" "playerctl previous")
      ];

      rule =
        field: pattern: attrs:
        { match.${field} = pattern; } // attrs;

      bezierCurve = name: p1: p2: {
        _args = [
          name
          {
            type = "bezier";
            points = [
              p1
              p2
            ];
          }
        ];
      };

      animation =
        leaf: speed: bezier: style:
        {
          inherit leaf speed bezier;
          enabled = true;
        }
        // lib.optionalAttrs (style != null) { inherit style; };

      workspaceBinds = builtins.concatLists (
        builtins.genList (
          i:
          let
            ws = toString (i + 1);
          in
          [
            (actionBind "${mainMod} + code:1${toString i}" (lua ''hl.dsp.focus({ workspace = "${ws}" })''))
            (actionBind "${mainMod} + SHIFT + code:1${toString i}" (
              lua ''hl.dsp.window.move({ workspace = "${ws}" })''
            ))
          ]
        ) 9
      );
    in
    {
      wayland.windowManager.hyprland.extraConfig = ''
        local workspace_programs = {
          ["special:ai"] = ${builtins.toJSON "${webApp}=https://www.perplexity.ai/"},
          ["special:dev"] = ${builtins.toJSON terminal},
          ["special:media"] = ${builtins.toJSON "${webApp}=https://www.youtube.com/"},
          ["special:think"] = ${builtins.toJSON "${webApp}=https://draw.${domain}/"},
        }

        hl.on("workspace.created", function(ws)
          if not ws.is_empty then return end
          local command = workspace_programs[ws.name]
          if command then
            hl.exec_cmd(command, { workspace = ws.name .. " silent" })
          end
        end)
      '';
      wayland.windowManager.hyprland.settings = {
        mainMod._var = mainMod;

        config = {
          ecosystem = {
            no_update_news = true;
            no_donation_nag = true;
          };

          animations.enabled = true;

          input = {
            numlock_by_default = true;
            follow_mouse = 1;
            sensitivity = -0.1;
            force_no_accel = 0;
            kb_layout = "us";
          };

          render.direct_scanout = 0;
          master.new_status = "master";

          general = {
            allow_tearing = false;
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

          cursor.hide_on_key_press = true;

          decoration = {
            rounding = 10;
            active_opacity = 1;
            inactive_opacity = 1;
            blur.enabled = false;
            shadow = {
              enabled = true;
              render_power = 3;
              range = 4;
              color = lib.mkForce "rgba(1a1a1aee)";
            };
          };

          misc = {
            mouse_move_enables_dpms = true;
            key_press_enables_dpms = true;
            force_default_wallpaper = 0;
            focus_on_activate = true;
          };
        };

        bind = binds ++ mediaBinds ++ workspaceBinds;
        window_rule = [
          (rule "class" "^(kitty)$" { no_blur = true; })
          (rule "class" "^(kitty)$" { opacity = "1.0 1.0 1.0 override"; })
          (rule "initial_class" "^(Chromium-browser)$" { tile = true; })
          (rule "title" "^(Picture-in-Picture)$" { float = true; })
          (rule "title" "^(Picture-in-Picture)$" { pin = true; })
        ]
        ++ map (title: rule "title" title { workspace = "special silent"; }) [
          "^(Firefox — Sharing Indicator)$"
          "^(Zen — Sharing Indicator)$"
          "^(.*is sharing (your screen|a window).)$"
        ];

        workspace_rule = host.hardwareConfig.workspace;
        inherit (host.hardwareConfig) monitor;

        curve = [
          (bezierCurve "easeInExpo" [ 0.7 0 ] [ 0.84 0 ])
          (bezierCurve "easeOutExpo" [ 0.16 1 ] [ 0.3 1 ])
        ];

        animation = [
          (animation "windows" 1 "easeInExpo" "slide")
          (animation "windowsIn" 1 "easeInExpo" "slide 80%")
          (animation "windowsOut" 1 "easeOutExpo" "slide 80%")
          (animation "border" 10 "default" null)
          (animation "borderangle" 8 "default" null)
          (animation "fade" 2 "default" null)
          {
            leaf = "workspaces";
            enabled = false;
          }
        ];
      };
    };
}

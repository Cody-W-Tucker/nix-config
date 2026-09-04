{
  config,
  lib,
  hardwareConfig,
  ...
}:

let
  mainMod = "SUPER";
  browser = "zen --new-tab";
  webApp = "chromium --new-window --app";
  terminal = "kitty";

  lua = lib.generators.mkLuaInline;

  # Dispatcher calls rendered as raw Lua expressions for bind actions
  exec = cmd: lua "hl.dsp.exec_cmd(${builtins.toJSON cmd})";

  # Helper to focus or run applications (renders a single hl.dsp.exec_cmd call)
  focusOrRun = appClass: cmd: lua ''hl.dsp.exec_cmd("focus-or-run '${appClass}' '${cmd}'")'';

  # One bind: { _args = [ key action (options)? ] } renders hl.bind(key, action[, options])
  mkBind = key: action: options: {
    _args = [
      key
      action
    ]
    ++ lib.optionals (options != null) [ options ];
  };

  execBind = key: cmd: mkBind key (exec cmd) null;
  actionBind = key: action: mkBind key action null;

  # Drag/resize binds need the mouse option flag (replaces hyprlang bindm)
  mouseBind = key: action: mkBind key action { mouse = true; };

  specialWorkspaceRules = [
    {
      workspace = "special:ai";
      on_created_empty = "${webApp}=https://www.perplexity.ai/";
    }
    {
      workspace = "special:dev";
      on_created_empty = terminal;
    }
    {
      workspace = "special:media";
      on_created_empty = "${webApp}=https://www.youtube.com/";
    }
    {
      workspace = "special:think";
      on_created_empty = "${webApp}=https://draw.homehub.tv/";
    }
    {
      workspace = "special:chat";
      on_created_empty = "${terminal} -e twt";
    }
    {
      workspace = "special:stream-manager";
      on_created_empty = "${webApp}=https://dashboard.twitch.tv/u/cody_tmv/stream-manager";
    }
  ];

  binds = [
    # Move/resize windows with mainMod + LMB/RMB and dragging
    (mouseBind "${mainMod} + mouse:272" (lua "hl.dsp.window.drag()"))
    (mouseBind "${mainMod} + mouse:273" (lua "hl.dsp.window.resize()"))

    # Application launchers (focus existing window or run new)
    (execBind "${mainMod} + Q" terminal)
    (actionBind "${mainMod} + 0" (focusOrRun "^(zen)$" browser))

    # Web applications
    (execBind "${mainMod} + SHIFT + Return" "[workspace special:ai] ${webApp}=https://grok.com/")
    (execBind "${mainMod} + A" "${webApp}=https://chat.homehub.tv/")

    # Quick launch
    (execBind "${mainMod} + Tab" "rofi-launcher")
    (execBind "${mainMod} + V" "cliphist list | rofi -dmenu | cliphist decode | wl-copy")
    (execBind "${mainMod} + SHIFT + Tab" "web-search")
    (execBind "${mainMod} + BackSpace" "rofi -show calc -modi calc -no-show-match -no-sort -calc-command 'echo -n \"{result}\" | wl-copy'")

    # Screenshots
    (execBind "${mainMod} + S" "screenshot-ocr")
    (execBind "${mainMod} + SHIFT + S" ''grim -g "$(slurp)" - | wl-copy'')

    # Color picker
    (execBind "${mainMod} + mouse:274" "hyprpicker -a")

    # Window management
    (actionBind "${mainMod} + C" (lua "hl.dsp.window.close()"))
    (actionBind "${mainMod} + F" (
      lua ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })''
    ))

    # Workspace navigation
    (actionBind "${mainMod} + H" (lua ''hl.dsp.focus({ direction = "l" })''))
    (execBind "${mainMod} + SHIFT + H" "hyprnome --previous --move")
    (actionBind "${mainMod} + L" (lua ''hl.dsp.focus({ direction = "r" })''))
    (execBind "${mainMod} + SHIFT + L" "hyprnome --move")

    (execBind "${mainMod} + mouse_down" "hyprnome --previous")
    (execBind "${mainMod} + mouse_up" "hyprnome")
    (execBind "${mainMod} + SHIFT + mouse_down" "hyprnome --previous --move")
    (execBind "${mainMod} + SHIFT + mouse_up" "hyprnome --move")

    # Special workspaces
    (actionBind "${mainMod} + Return" (lua ''hl.dsp.workspace.toggle_special("ai")''))
    (actionBind "${mainMod} + T" (lua ''hl.dsp.workspace.toggle_special("chat")''))
    (actionBind "${mainMod} + SHIFT + T" (lua ''hl.dsp.workspace.toggle_special("stream-manager")''))
    (actionBind "${mainMod} + D" (lua ''hl.dsp.workspace.toggle_special("dev")''))
    # agent runner
    (execBind "${mainMod} + SHIFT + D" "[workspace special:dev] ${terminal} -e herdr")
    (actionBind "${mainMod} + E" (lua ''hl.dsp.workspace.toggle_special("think")''))
    (actionBind "${mainMod} + Y" (lua ''hl.dsp.workspace.toggle_special("media")''))
    (execBind "${mainMod} + SHIFT + Y" "[workspace special:media] ${webApp}=https://www.twitch.tv/")

    # Toggle waybar
    (execBind "${mainMod} + P" "pkill -SIGUSR1 waybar")

    # Whisper dictation - toggle recording on/off
    (execBind "${mainMod} + Escape" "llama-dictate toggle")

    # Whisper dictation - recover from orphaned recorder
    (execBind "${mainMod} + SHIFT + Escape" "llama-dictate recover")
  ];

  # Multimedia keys for volume, mic, and LCD brightness (bindel: locked + repeating)
  repeatingExecBinds =
    builtins.map
      (
        spec:
        mkBind spec.key (exec spec.command) {
          locked = true;
          repeating = true;
        }
      )
      [
        {
          key = "XF86AudioRaiseVolume";
          command = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
        }
        {
          key = "XF86AudioLowerVolume";
          command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        }
        {
          key = "XF86AudioMute";
          command = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        }
        {
          key = "XF86AudioMicMute";
          command = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        }
        {
          key = "XF86MonBrightnessUp";
          command = "brightnessctl -e4 -n2 set 5%+";
        }
        {
          key = "XF86MonBrightnessDown";
          command = "brightnessctl -e4 -n2 set 5%-";
        }
      ];

  # Locking binds that don't repeat (bindl)
  lockedExecBinds = builtins.map (spec: mkBind spec.key (exec spec.command) { locked = true; }) [
    # Requires playerctl
    {
      key = "XF86AudioNext";
      command = "playerctl next";
    }
    {
      key = "XF86AudioPause";
      command = "playerctl play-pause";
    }
    {
      key = "XF86AudioPlay";
      command = "playerctl play-pause";
    }
    {
      key = "XF86AudioPrev";
      command = "playerctl previous";
    }
  ];

  # workspaces
  # binds $mainMod + [shift +] {1..9} to [move to] workspace {1..9}
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
  wayland.windowManager.hyprland.settings = {
    # Exposes the old `$mainMod` hyprlang variable as a Lua local
    mainMod = {
      _var = mainMod;
    };

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

      render = {
        direct_scanout = 0;
      };

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

      cursor = {
        hide_on_key_press = true;
      };

      decoration = {
        rounding = 10;
        active_opacity = 1;
        inactive_opacity = 1;
        blur = {
          enabled = false;
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

    bind = binds ++ repeatingExecBinds ++ lockedExecBinds ++ workspaceBinds;

    window_rule = [
      # Kitty
      {
        match.class = "^(kitty)$";
        no_blur = true;
      }
      {
        match.class = "^(kitty)$";
        opacity = "1.0 1.0 1.0 override";
      }

      # Ensure all web apps don't float
      {
        match.initial_class = "^(Chromium-browser)$";
        tile = true;
      }
      {
        match.title = "^(Picture-in-Picture)$";
        float = true;
      }
      {
        match.title = "^(Picture-in-Picture)$";
        pin = true;
      }

      # Throw sharing indicators away
      {
        match.title = "^(Firefox — Sharing Indicator)$";
        workspace = "special silent";
      }
      {
        match.title = "^(Zen — Sharing Indicator)$";
        workspace = "special silent";
      }
      {
        match.title = "^(.*is sharing (your screen|a window).)$";
        workspace = "special silent";
      }
    ];

    # Workspace and monitor set in flake.nix
    workspace_rule = hardwareConfig.workspace ++ specialWorkspaceRules;
    monitor = hardwareConfig.monitor;

    # Custom curves used by the animation entries below
    curve = [
      {
        _args = [
          "easeInExpo"
          {
            type = "bezier";
            points = [
              [
                0.7
                0
              ]
              [
                0.84
                0
              ]
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
              [
                0.16
                1
              ]
              [
                0.3
                1
              ]
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

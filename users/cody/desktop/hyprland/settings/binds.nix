{ lib, ... }:

let
  mainMod = "SUPER";
  browser = "uwsm app -- zen --new-tab";
  webApp = "uwsm app -- chromium --new-window --app";
  terminal = "uwsm app -- kitty";

  lua = lib.generators.mkLuaInline;

  # Helper to keep dispatcher calls readable in lua mode
  exec = cmd: lua "hl.dsp.exec_cmd(${builtins.toJSON cmd})";

  # Helper to focus or run applications
  focusOrRun = appClass: cmd: exec "focus-or-run '${appClass}' '${cmd}'";

  renderBind = key: action: options: {
    _args = [ key action ] ++ lib.optional (options != null) options;
  };

  renderCommandBind = spec:
    renderBind spec.key (exec spec.command) (spec.options or null);

  renderActionBind = spec:
    renderBind spec.key spec.action (spec.options or null);

  renderHoldBind = spec: [
    (renderBind spec.key (exec spec.start) null)
    (renderBind spec.key (exec spec.stop) { release = true; })
  ];

  renderKeyCommandEntry = key: command:
    renderCommandBind {
      inherit key command;
    };

  renderKeyActionEntry = key: action:
    renderActionBind {
      inherit key action;
    };

  renderKeyActionPair = pair:
    renderKeyActionEntry (builtins.elemAt pair 0) (builtins.elemAt pair 1);

  commandBinds = {
    # Application launchers (focus existing window or run new)
    "${mainMod} + Q" = terminal;

    # Web applications
    "${mainMod} + SHIFT + Return" = "[workspace special:ai] ${webApp}=https://grok.com/";
    "${mainMod} + A" = "${webApp}=https://ai.homehub.tv/";

    # Quick launch
    "${mainMod} + Tab" = "rofi-launcher";
    "${mainMod} + V" = "cliphist list | rofi -dmenu | cliphist decode | wl-copy";
    "${mainMod} + SHIFT + Tab" = "web-search";
    "${mainMod} + BackSpace" = "rofi -show calc -modi calc -no-show-match -no-sort -calc-command 'echo -n \"{result}\" | wl-copy'";

    # Screenshots
    "${mainMod} + S" = "screenshot-ocr";
    "${mainMod} + SHIFT + S" = ''grim -g "$(slurp)" - | wl-copy'';

    # Toggle waybar
    "${mainMod} + P" = "pkill -SIGUSR1 waybar";

    # Workspace navigation
    "${mainMod} + SHIFT + H" = "hyprnome --previous --move";
    "${mainMod} + SHIFT + L" = "hyprnome --move";
    "${mainMod} + mouse_down" = "hyprnome --previous";
    "${mainMod} + mouse_up" = "hyprnome";
    "${mainMod} + SHIFT + mouse_down" = "hyprnome --previous --move";
    "${mainMod} + SHIFT + mouse_up" = "hyprnome --move";

    # Requires playerctl
    "XF86AudioNext" = "playerctl next";
    "XF86AudioPause" = "playerctl play-pause";
    "XF86AudioPlay" = "playerctl play-pause";
    "XF86AudioPrev" = "playerctl previous";
  };

  actionBinds = {
    # Move/resize windows with mainMod + LMB/RMB and dragging
    "${mainMod} + mouse:272" = lua "hl.dsp.window.drag()";
    "${mainMod} + mouse:273" = lua "hl.dsp.window.resize()";

    # Application launchers (focus existing window or run new)
    "${mainMod} + 0" = focusOrRun "^(zen)$" browser;

    # Window management
    "${mainMod} + C" = lua "hl.dsp.window.close()";
    "${mainMod} + F" = lua ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'';

    # Workspace navigation
    "${mainMod} + H" = lua ''hl.dsp.focus({ direction = "l" })'';
    "${mainMod} + L" = lua ''hl.dsp.focus({ direction = "r" })'';

    # Special workspaces
    "${mainMod} + Return" = lua ''hl.dsp.workspace.toggle_special("ai")'';
    "${mainMod} + D" = lua ''hl.dsp.workspace.toggle_special("dev")'';
    "${mainMod} + E" = lua ''hl.dsp.workspace.toggle_special("think")'';
    "${mainMod} + Y" = lua ''hl.dsp.workspace.toggle_special("media")'';
    "${mainMod} + SHIFT + Y" = lua ''hl.dsp.window.move({ workspace = "special:media", follow = false })'';
  };

  optionedCommandBinds = [
    # Color picker
    {
      key = "${mainMod} + mouse:274";
      command = "hyprpicker -a";
      options.mouse = true;
    }

    # Multimedia keys for volume and LCD brightness
    {
      key = "XF86AudioRaiseVolume";
      command = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
      options = {
        locked = true;
        repeating = true;
      };
    }
    {
      key = "XF86AudioLowerVolume";
      command = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      options = {
        locked = true;
        repeating = true;
      };
    }
    {
      key = "XF86AudioMute";
      command = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      options.locked = true;
    }
    {
      key = "XF86AudioMicMute";
      command = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      options.locked = true;
    }
    {
      key = "XF86MonBrightnessUp";
      command = "brightnessctl -e4 -n2 set 5%+";
      options = {
        locked = true;
        repeating = true;
      };
    }
    {
      key = "XF86MonBrightnessDown";
      command = "brightnessctl -e4 -n2 set 5%-";
      options = {
        locked = true;
        repeating = true;
      };
    }
    {
      key = "XF86AudioNext";
      command = "playerctl next";
      options.locked = true;
    }
    {
      key = "XF86AudioPause";
      command = "playerctl play-pause";
      options.locked = true;
    }
    {
      key = "XF86AudioPlay";
      command = "playerctl play-pause";
      options.locked = true;
    }
    {
      key = "XF86AudioPrev";
      command = "playerctl previous";
      options.locked = true;
    }
  ];

  holdBinds = [
    # Whisper dictation - hold to record, release to transcribe
    {
      key = "${mainMod} + Escape";
      start = "whisp-away-safe start";
      stop = "whisp-away-safe stop";
    }
  ];

  workspaceActionBinds = builtins.concatLists (
    builtins.genList (
      i:
      let
        ws = toString (i + 1);
        key = "code:1${toString i}";
      in
      [
        [ "${mainMod} + ${key}" (lua ''hl.dsp.focus({ workspace = "${ws}" })'') ]
        [ "${mainMod} + SHIFT + ${key}" (lua ''hl.dsp.window.move({ workspace = "${ws}" })'') ]
      ]
    ) 9
  );
in
{
  wayland.windowManager.hyprland.settings.bind =
    (lib.mapAttrsToList renderKeyCommandEntry commandBinds)
    ++ (lib.mapAttrsToList renderKeyActionEntry actionBinds)
    ++ (map renderCommandBind optionedCommandBinds)
    ++ (lib.concatMap renderHoldBind holdBinds)
    ++ (map renderKeyActionPair workspaceActionBinds);
}

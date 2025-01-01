{ config, ... }:
let
  mainMod = "SUPER";

  mousebinds = [
    # Move/resize windows with mainMod + LMB/RMB and dragging
    "${mainMod}, mouse:272, movewindow"
    "${mainMod}, mouse:273, resizewindow"
  ];

  keybinds = [
    # Application launchers
    "${mainMod}, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
    "${mainMod}, V, exec, keybind-logger 'cliphist list | rofi -dmenu | cliphist decode | wl-copy'"
    "${mainMod}, RETURN, exec, pkill waybar && waybar &"
    "${mainMod}, RETURN, exec, keybind-logger 'pkill waybar && waybar &'"
    "${mainMod}, Q, exec, kitty"
    "${mainMod}, Q, exec, keybind-logger 'kitty'"
    "${mainMod}, E, exec, kitty -- ranger"
    "${mainMod}, E, exec, keybind-logger 'kitty -- ranger'"
    "${mainMod} SHIFT, Tab, exec, rofi-launcher"
    "${mainMod} SHIFT, Tab, exec, keybind-logger 'rofi-launcher'"
    "${mainMod}, Tab, exec, google-chrome-stable"
    "${mainMod}, Tab, exec, keybind-logger 'google-chrome-stable'"
    "${mainMod} SHIFT, E, exec, nautilus"
    "${mainMod} SHIFT, E, exec, keybind-logger 'nautilus'"
    "${mainMod} SHIFT, Q, exec, rofi -show web_scraper -modi 'web_scraper:web-scraper'"
    "${mainMod} SHIFT, Q, exec, keybind-logger 'rofi -show web_scraper -modi 'web_scraper:web-scraper''"

    # Quick launch apps
    "${mainMod}, KP_Insert, exec, google-chrome-stable --app=https://ai.homehub.tv"
    "${mainMod}, KP_Insert, exec, keybind-logger 'google-chrome-stable --app=https://ai.homehub.tv'"
    "${mainMod}, KP_Add, exec, hyprctl dispatch exec [floating] gnome-calculator"
    "${mainMod}, KP_Add, exec, keybind-logger 'hyprctl dispatch exec [floating] gnome-calculator'"
    "${mainMod}, KP_End, exec, google-chrome-stable --app=https://mail.google.com"
    "${mainMod}, KP_End, exec, keybind-logger 'google-chrome-stable --app=https://mail.google.com'"
    "${mainMod}, KP_Down, exec, google-chrome-stable --app=https://messages.google.com/web/u/0/conversations"
    "${mainMod}, KP_Down, exec, keybind-logger 'google-chrome-stable --app=https://messages.google.com/web/u/0/conversations'"
    "${mainMod}, KP_Next, exec, google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r"
    "${mainMod}, KP_Next, exec, keybind-logger 'google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r'"
    "${mainMod}, KP_Home, exec, code"
    "${mainMod}, KP_Home, exec, keybind-logger 'code'"

    # Screenshots
    ''${mainMod}, S, exec, grim -g "$(slurp)" "$HOME/Pictures/Screenshots/$(date '+%y%m%d_%H-%M-%S').png"''
    ''${mainMod} SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''

    # Color picker
    "${mainMod}, mouse:274, exec, hyprpicker -a"
    "${mainMod}, mouse:275, exec, keybind-logger 'hyprpicker -a'"

    # Workspace navigation
    "${mainMod}, mouse_down, exec, hyprnome --previous"
    "${mainMod}, mouse_up, exec, hyprnome"
    "${mainMod} SHIFT, mouse_down, exec, hyprnome --previous --move"
    "${mainMod} SHIFT, mouse_up, exec, hyprnome --move"

    # Window management
    "${mainMod}, SPACE, togglefloating"
    "${mainMod}, C, killactive"
    "${mainMod}, F, fullscreen"
    "${mainMod} SHIFT, P, fullscreenstate"
    "${mainMod}, P, pin"

    # Focus movement
    "${mainMod}, left, movefocus, l"
    "${mainMod}, right, movefocus, r"
    "${mainMod}, up, movefocus, u"
    "${mainMod}, down, movefocus, d"

    # Window movement
    "${mainMod} SHIFT, left, movewindow, l"
    "${mainMod} SHIFT, right, movewindow, r"
    "${mainMod} SHIFT, up, movewindow, u"
    "${mainMod} SHIFT, down, movewindow, d"

    # Scratchpad
    "${mainMod}, A, togglespecialworkspace, magic"
    "${mainMod} SHIFT, A, movetoworkspacesilent, special:magic"
  ];
in
{
  wayland.windowManager.hyprland.settings = {
    "$mainMod" = mainMod;
    bindm = mousebinds;
    bind = keybinds;
  };
}

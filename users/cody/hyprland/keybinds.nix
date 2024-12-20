{ config, ... }:
{
  # Keybindings
  "$mainMod" = "SUPER";
  bindm =
    [
      # Move/resize windows with mainMod + LMB/RMB and dragging
      "$mainMod, mouse:272, movewindow"
      "$mainMod, mouse:273, resizewindow"
    ];
  bind =
    [
      "$mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
      "$mainMod, RETURN, exec, pkill waybar && waybar &"
      "$mainMod, Q, exec, kitty"
      "$mainMod, E, exec, kitty -- ranger"
      "$mainMod, Tab, exec, rofi-launcher"
      "$mainMod SHIFT, E, exec, nautilus"
      "$mainMod SHIFT, Tab, exec, rofi -show web_scraper -modi 'web_scraper:web-scraper'"
      "$mainMod, KP_Insert, exec, google-chrome-stable --app=https://ai.homehub.tv"
      "$mainMod, KP_Add, exec, hyprctl dispatch exec [floating] gnome-calculator"
      "$mainMod, KP_End, exec, google-chrome-stable --app=https://mail.google.com"
      "$mainMod, KP_Down, exec, google-chrome-stable --app=https://messages.google.com/web/u/0/conversations"
      "$mainMod, KP_Next, exec, google-chrome-stable --app=https://calendar.google.com/calendar/u/0/r"
      "$mainMod, KP_Home, exec, code"
      # Screenshots
      ''$mainMod, S, exec, grim -g "$(slurp)" "$HOME/Pictures/Screenshots/$(date '+%y%m%d_%H-%M-%S').png"''
      ''$mainMod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''
      # Hyprpicker color picker
      "$mainMod, mouse:274, exec, hyprpicker -a"
      # Switching workspaces
      "$mainMod, mouse_down, exec, hyprnome --previous"
      "$mainMod, mouse_up, exec, hyprnome"
      # Moving windows to workspaces
      "$mainMod SHIFT, mouse_down, exec, hyprnome --previous --move"
      "$mainMod SHIFT, mouse_up, exec, hyprnome --move"

      # Unlogged keybinds
      "$mainMod, SPACE, togglefloating"
      "$mainMod, C, killactive"
      "$mainMod, F, fullscreen"
      "$mainMod SHIFT, P, fullscreenstate"
      "$mainMod, P, pin"
      # Move focus with mainMod + arrow keys
      "$mainMod, left, movefocus, l"
      "$mainMod, right, movefocus, r"
      "$mainMod, up, movefocus, u"
      "$mainMod, down, movefocus, d"
      # Move windows with mainMod + shift + arrow keys
      "$mainMod SHIFT, left, movewindow, l"
      "$mainMod SHIFT, right, movewindow, r"
      "$mainMod SHIFT, up, movewindow, u"
      "$mainMod SHIFT, down, movewindow, d"
      # Special workspace (scratchpad)
      "$mainMod, A, togglespecialworkspace, magic"
      "$mainMod SHIFT, A, movetoworkspacesilent, special:magic"
    ];
}

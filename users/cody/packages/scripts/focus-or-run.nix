{ pkgs }:

pkgs.writeShellScriptBin "focus-or-run" ''
  # Focus an existing window by class, or launch the application if not found
  # Usage: focus-or-run <window_class> <command_to_run>

  APP_CLASS="$1"
  APP_CMD="$2"

  # Get window address directly using hyprctl and jq
  WINDOW_ADDRESS=$(${pkgs.hyprland}/bin/hyprctl clients -j | ${pkgs.jq}/bin/jq -r --arg a "$APP_CLASS" '.[] | select(.class | test($a; "i")) | .address' | head -n1)

  if [ -n "$WINDOW_ADDRESS" ]; then
    ${pkgs.hyprland}/bin/hyprctl dispatch focuswindow "address:$WINDOW_ADDRESS"
  else
    $APP_CMD &
  fi
''

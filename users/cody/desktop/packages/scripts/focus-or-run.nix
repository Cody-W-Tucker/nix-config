{ pkgs }:

pkgs.writeShellApplication {
  name = "focus-or-run";
  runtimeInputs = [
    pkgs.hyprland
    pkgs.jq
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail

    # Focus an existing window by class, or launch the application if not found
    # Usage: focus-or-run <window_class> <command_to_run>

    APP_CLASS="$1"
    APP_CMD="$2"
    APP_KEY="''${APP_CLASS%% *}"
    APP_KEY="''${APP_KEY##*/}"

    # Get window address directly using hyprctl and jq
    WINDOW_ADDRESS=$(hyprctl clients -j | jq -r --arg a "$APP_CLASS" --arg key "$APP_KEY" 'first(.[] | select((try (.class | test("^(?:" + $a + ")$"; "i")) catch false) or (.class | ascii_downcase == ($key | ascii_downcase))) | .address) // empty')

    if [ -n "$WINDOW_ADDRESS" ]; then
      hyprctl dispatch focuswindow "address:$WINDOW_ADDRESS"
    else
      $APP_CMD &
    fi
  '';
}

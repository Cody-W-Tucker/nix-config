{ pkgs }:

pkgs.writeShellApplication {
  name = "focus-or-run";
  runtimeInputs = [
    pkgs.hyprland
    pkgs.jq
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.systemd
  ];
  text = ''
    set -euo pipefail

    # Focus an existing window by class, or launch the application if not found
    # Usage: focus-or-run <window_class> <command_to_run>

    APP_CLASS="$1"
    APP_CMD="$2"
    APP_KEY="''${APP_CLASS%% *}"
    APP_KEY="''${APP_KEY##*/}"

    activate_tray_item() {
      if ! busctl --user --quiet status org.kde.StatusNotifierWatcher >/dev/null 2>&1; then
        return 1
      fi

      while IFS= read -r item; do
        service="''${item%%/*}"
        path="/''${item#*/}"
        title=$(busctl --user --json=short get-property "$service" "$path" org.kde.StatusNotifierItem Title 2>/dev/null | jq -r '.data // ""' || true)
        tooltip=$(busctl --user --json=short get-property "$service" "$path" org.kde.StatusNotifierItem ToolTip 2>/dev/null | jq -r '.data[2] // ""' || true)

        if printf '%s\n%s\n' "$title" "$tooltip" | grep -Fqi "$APP_KEY"; then
          busctl --user call "$service" "$path" org.kde.StatusNotifierItem Activate ii 0 0 >/dev/null
          return 0
        fi
      done < <(
        busctl --user --json=short get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems \
          | jq -r '.data[]' \
          || true
      )

      return 1
    }

    # Get window address directly using hyprctl and jq
    WINDOW_ADDRESS=$(hyprctl clients -j | jq -r --arg a "$APP_CLASS" --arg key "$APP_KEY" 'first(.[] | select((try (.class | test("^(?:" + $a + ")$"; "i")) catch false) or (.class | ascii_downcase == ($key | ascii_downcase))) | .address) // empty')

    if [ -n "$WINDOW_ADDRESS" ]; then
      hyprctl dispatch focuswindow "address:$WINDOW_ADDRESS"
    elif activate_tray_item; then
      :
    else
      $APP_CMD &
    fi
  '';
}

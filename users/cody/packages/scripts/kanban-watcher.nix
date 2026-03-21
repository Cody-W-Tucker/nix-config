{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.kanban-watcher;

  kanban-watcher-script = pkgs.writeShellScriptBin "kanban-watcher" ''
    set -euo pipefail

    # Kanban Watcher - Monitors window titles and auto-routes to kanban lanes
    POLL_INTERVAL=2
    declare -A NOTIFIED_DONE

    # Map title prefixes to kanban workspaces
    get_kanban_workspace() {
      local title="$1"
      if [[ "$title" =~ ^\[DONE\] ]]; then
        echo "special:kanban-done"
      elif [[ "$title" =~ ^\[REVIEW\] ]]; then
        echo "special:kanban-review"
      elif [[ "$title" =~ ^\[PROGRESS\] ]]; then
        echo "special:kanban-progress"
      elif [[ "$title" =~ ^\[INIT\] ]]; then
        echo "special:kanban-init"
      else
        echo ""
      fi
    }

    # Check all windows and route if needed
    poll_windows() {
      local clients
      clients=$(${pkgs.hyprland}/bin/hyprctl clients -j 2>/dev/null || echo "[]")

      # Process each window
      echo "$clients" | ${pkgs.jq}/bin/jq -c '.[]' 2>/dev/null | while read -r window; do
        local address title class current_ws target_ws

        address=$(echo "$window" | ${pkgs.jq}/bin/jq -r '.address // empty')
        title=$(echo "$window" | ${pkgs.jq}/bin/jq -r '.title // empty')
        class=$(echo "$window" | ${pkgs.jq}/bin/jq -r '.class // empty')
        current_ws=$(echo "$window" | ${pkgs.jq}/bin/jq -r '.workspace.name // empty')

        # Skip if no address or title
        [[ -z "$address" || -z "$title" ]] && continue

        # Only process terminal windows
        [[ ! "$class" =~ ^(kitty|foot|wezterm|alacritty) ]] && continue

        # Determine target kanban workspace from title
        target_ws=$(get_kanban_workspace "$title")

        # Skip if no kanban prefix or already in correct workspace
        [[ -z "$target_ws" ]] && continue
        [[ "$current_ws" == "$target_ws" ]] && continue

        # Move window to target workspace
        ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspacesilent "$target_ws","address:$address" 2>/dev/null || true

        # Send notification when task reaches DONE for the first time
        if [[ "$target_ws" == "special:kanban-done" ]]; then
          local window_key="''${address}"
          if [[ -z "''${NOTIFIED_DONE[$window_key]:-}" ]]; then
            ${pkgs.libnotify}/bin/notify-send "Task Complete" "''${title#\[DONE\] }"
            NOTIFIED_DONE["$window_key"]="1"
          fi
        fi
      done
    }

    # Main loop - poll continuously
    echo "Kanban watcher started. Monitoring for [INIT], [PROGRESS], [REVIEW], [DONE] titles..."

    # Continuous polling loop
    while true; do
      poll_windows
      sleep "$POLL_INTERVAL"
    done
  '';
in

{
  options.services.kanban-watcher = {
    enable = mkEnableOption "Hyprland Kanban Watcher - auto-routes windows through kanban lanes based on title prefixes";

    package = mkOption {
      type = types.package;
      default = kanban-watcher-script;
      description = "The kanban-watcher package to use";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.kanban-watcher = {
      Unit = {
        Description = "Hyprland Kanban Window Watcher";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/kanban-watcher";
        Restart = "always";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}

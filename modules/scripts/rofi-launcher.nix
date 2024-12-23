{ pkgs }:
pkgs.writeShellScriptBin "rofi-launcher" ''
  #!/bin/bash

  # Check if Rofi is already running and kill it if so
  if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
  fi

  # Show Rofi menu and select a desktop entry
  DESKTOP_ENTRY=$(rofi -show drun -show-icons -format 'd' -no-lazy-grab)

  # Exit if no selection was made
  if [[ -z "$DESKTOP_ENTRY" ]]; then
    exit 0
  fi

  # Search for .desktop file in NixOS paths
  DESKTOP_FILE=""
  for path in \
    "$HOME/.local/share/applications" \
    "/etc/profiles/per-user/$USER/share/applications" \
    "/run/current-system/sw/share/applications"; do
      if [[ -f "$path/$DESKTOP_ENTRY" ]]; then
        DESKTOP_FILE="$path/$DESKTOP_ENTRY"
        break
      fi
  done

  # If .desktop file isn't found, exit with an error
  if [[ -z "$DESKTOP_FILE" ]]; then
    echo "ERROR: Could not locate .desktop file for: $DESKTOP_ENTRY"
    exit 1
  fi

  # Extract the 'Name' (app name) and 'Exec' (command) from the .desktop file
  APP_NAME=$(grep -m 1 '^Name=' "$DESKTOP_FILE" | cut -d '=' -f 2)
  EXEC_CMD=$(grep -m 1 '^Exec=' "$DESKTOP_FILE" | cut -d '=' -f 2 | sed 's/%[a-zA-Z]//g')

  # Log the app name with the logger
  if [[ -n "$APP_NAME" ]]; then
    rofi-logger "$APP_NAME"
  fi

  # Launch the executable command
  if [[ -n "$EXEC_CMD" ]]; then
    setsid $EXEC_CMD >/dev/null 2>&1 &
  else
    echo "ERROR: No executable command found for: $APP_NAME"
  fi
''

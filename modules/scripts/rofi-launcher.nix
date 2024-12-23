{ pkgs }:
pkgs.writeShellScriptBin "rofi-launcher" ''
  #!/bin/bash

  LOG_FILE="/tmp/rofi_usage.log"

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

  # Find the Exec and Name fields in the selected .desktop file
  APP_NAME=$(grep -m 1 '^Name=' "$HOME/.local/share/applications/$DESKTOP_ENTRY" | cut -d '=' -f 2)
  EXEC_CMD=$(grep -m 1 '^Exec=' "$HOME/.local/share/applications/$DESKTOP_ENTRY" | cut -d '=' -f 2 | sed 's/%[a-zA-Z]//g')

  # Use default system-wide .desktop files if not found in local directory
  if [[ -z "$APP_NAME" ]]; then
    APP_NAME=$(grep -m 1 '^Name=' "/usr/share/applications/$DESKTOP_ENTRY" | cut -d '=' -f 2)
    EXEC_CMD=$(grep -m 1 '^Exec=' "/usr/share/applications/$DESKTOP_ENTRY" | cut -d '=' -f 2 | sed 's/%[a-zA-Z]//g')
  fi

  # If no valid app was found, exit
  if [[ -z "$APP_NAME" || -z "$EXEC_CMD" ]]; then
    echo "ERROR: Could not locate .desktop entry or executable command for $DESKTOP_ENTRY"
    exit 1
  fi

  # Log the app launch
  rofi-logger "$APP_NAME"

  # Launch the executable command
  setsid $EXEC_CMD >/dev/null 2>&1 &
''

{ pkgs }:
pkgs.writeShellScriptBin "rofi-launcher" ''
  #!/bin/bash

  # Check if Rofi is already running and kill it if so
  if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
  fi

  # Launch Rofi and capture the selected app name
  SELECTED_APP=$(rofi -show drun -show-icons -format 's')

  # Exit if no selection was made
  if [[ -z "$SELECTED_APP" ]]; then
    exit 0
  fi

  # Log the selected app using the logger script
  rofi-logger "$SELECTED_APP"

  # Attempt to launch the selected application
  setsid "$SELECTED_APP" >/dev/null 2>&1 &
''

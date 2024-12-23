{ pkgs }:
pkgs.writeShellScriptBin "rofi-launcher" ''
  #!/bin/bash

  # Check if Rofi is already running and kill it if so
  if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
  fi

  # Launch Rofi and capture the selected app from the user
  SELECTED_APP=$(rofi -show drun -show-icons)

  # Log the selected app using the `rofi-logger` script
  if [[ -n "$SELECTED_APP" ]]; then
    rofi-logger "$SELECTED_APP"
    # Attempt to launch the selected app
    setsid $SELECTED_APP >/dev/null 2>&1 &
  fi
''

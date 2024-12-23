{ pkgs }:
pkgs.writeShellScriptBin "rofi-launcher" ''
  #!/bin/bash
  LOG_FILE="/tmp/rofi_usage.log"

  if pgrep -x "rofi" > /dev/null; then
    # Rofi is running, kill it
    pkill -x rofi
    exit 0
  fi

  # Launch rofi and get the selected application
  SELECTED_APP=$(rofi -show drun -show-icons)

  # Get current timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Log the launched application with timestamp
  echo "$timestamp | Launched $SELECTED_APP" >> "$LOG_FILE"

  # Launch the selected application
  $SELECTED_APP
''

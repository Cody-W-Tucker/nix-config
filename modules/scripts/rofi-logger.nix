{ pkgs }:
pkgs.writeShellScriptBin "rofi-logger" ''
  #!/bin/bash

  LOG_FILE="/tmp/rofi_usage.log"

  # Get the current timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # If provided, log the argument (the app name from the launcher)
  if [[ -n "$1" ]]; then
    echo "$timestamp | Launched: $1" >> "$LOG_FILE"
  fi
''

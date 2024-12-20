{ pkgs }:

pkgs.writeShellScriptBin "keybind-logger" ''
  #!/bin/bash

  LOG_FILE="/tmp/keybind_usage.log"
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  cmd="$*"

  # Log the keybind with timestamp and all arguments
  echo "$timestamp | \"$cmd\"" >> "$LOG_FILE" || {
    echo "Failed to write to log file" >&2
    exit 1
  }

  # Execute the command
  exec "$@"
''

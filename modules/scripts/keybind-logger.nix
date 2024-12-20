{ pkgs }:

pkgs.writeShellScriptBin "keybind-logger" ''
  #!/bin/bash

  LOG_FILE="/tmp/keybind_usage.log"
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  cmd="$*"

  # Log the keybind with timestamp and all arguments
  echo "$timestamp | $@" >> "$LOG_FILE"

  # Execute the command
  exec "$@"
''

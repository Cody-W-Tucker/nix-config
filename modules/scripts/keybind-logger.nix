{ pkgs }:

pkgs.writeShellScriptBin "keybind-logger" ''
  #!/bin/bash

  LOG_FILE="/tmp/keybind_usage.log"

  # Get current timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Log the keybind with timestamp
  echo "$timestamp | $1" >> "$LOG_FILE"
''

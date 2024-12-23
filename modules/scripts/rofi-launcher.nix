{ pkgs }:
pkgs.writeShellScriptBin "rofi-launcher" ''
  #!/bin/bash

  # Check if Rofi is already running and kill it if so
  if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
  fi



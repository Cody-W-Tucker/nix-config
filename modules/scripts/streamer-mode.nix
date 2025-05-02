{ pkgs }:

pkgs.writeShellScriptBin "streamer-mode" ''
#!/bin/bash

MODE="$1"
MONITOR="HDMI-A-4" # Change to your actual monitor name

if [ "$MODE" = "stream" ]; then
    # Set reserved area for 1920x1080 centered on 2560x1440
    hyprctl keyword monitor "$MONITOR,addreserved,0,0,320,320"
elif [ "$MODE" = "reset" ]; then
    # Remove reserved area (set all to 0)
    hyprctl keyword monitor "$MONITOR,addreserved,0,0,0,0"
else
    echo "Usage: $0 [stream|reset]"
fi
''
{ pkgs }:

pkgs.writeShellScriptBin "chromecast-stop" ''
  #!/usr/bin/env bash

  LOCK_FILE="/tmp/chromecast_screen_active"
  PID_FILE="/tmp/chromecast_screen_pids"

  if [ ! -f "$LOCK_FILE" ]; then
    ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "No active casting session"
    exit 0
  fi

  DEVICE=$(cat "$LOCK_FILE" 2>/dev/null || echo "Unknown device")

  ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "Stopping screen cast to $DEVICE..."

  # Kill all casting processes
  if [ -f "$PID_FILE" ]; then
    while read -r pid; do
      if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
      fi
    done < <(cat "$PID_FILE" | tr ' ' '\n')
    rm -f "$PID_FILE"
  fi

  # Kill any remaining processes
  pkill -f "wf-recorder.*chromecast" 2>/dev/null
  pkill -f "ffmpeg.*chromecast" 2>/dev/null

  rm -f "$LOCK_FILE"
  ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "Screen casting stopped"
''

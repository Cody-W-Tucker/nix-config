{ pkgs }:

pkgs.writeShellScriptBin "rofi-chromecast" ''
  #!/usr/bin/env bash

  LOCK_FILE="/tmp/chromecast_screen_active"
  PID_FILE="/tmp/chromecast_screen_pids"

  # Check if rofi is already running
  if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
  fi

  # Check if casting is currently active
  if [ -f "$LOCK_FILE" ]; then
    # Casting is active, offer to stop
    CHOICE=$(echo -e "Stop Casting\nCancel" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Screen Casting Active" \
      -theme-str 'imagebox { enabled: false; width: 0px; } window { height: 200px; }')
    
    if [ "$CHOICE" = "Stop Casting" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "Stopping screen cast..."
      
      # Kill all casting processes
      if [ -f "$PID_FILE" ]; then
        while read -r pid; do
          if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
          fi
        done < <(cat "$PID_FILE" | tr ' ' '\n')
        rm -f "$PID_FILE"
      fi
      
      # Kill any remaining ffmpeg or wf-recorder processes related to chromecast
      pkill -f "wf-recorder.*chromecast" 2>/dev/null
      pkill -f "ffmpeg.*chromecast" 2>/dev/null
      
      rm -f "$LOCK_FILE"
      ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "Screen casting stopped"
    fi
    exit 0
  fi

  # Discover devices
  DEVICES=$(${pkgs.go-chromecast}/bin/go-chromecast ls 2>/dev/null)

  if [ -z "$DEVICES" ]; then
    ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "No devices found on network"
    exit 1
  fi

  # Parse device names
  DEVICE_LIST=$(echo "$DEVICES" | grep "device_name=" | sed 's/.*device_name="\([^"]*\)".*/\1/')

  if [ -z "$DEVICE_LIST" ]; then
    ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "No devices found"
    exit 1
  fi

  # Select device
  SELECTED_DEVICE=$(echo "$DEVICE_LIST" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Cast Screen to" \
    -theme-str 'imagebox { enabled: false; width: 0px; } window { height: 400px; }')

  if [ -z "$SELECTED_DEVICE" ]; then
    exit 0
  fi

  ${pkgs.libnotify}/bin/notify-send -t 3000 "Chromecast" "Starting screen cast to $SELECTED_DEVICE..."

  # Create a temp directory for the stream
  STREAM_DIR=$(mktemp -d -t chromecast.XXXXXX)
  FIFO="$STREAM_DIR/screen.mkv"
  mkfifo "$FIFO"

  # Get screen dimensions from hyprland
  SCREEN_INFO=$(hyprctl monitors -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[0] | "\(.width)x\(.height)"')
  SCREEN_WIDTH=$(echo "$SCREEN_INFO" | cut -d'x' -f1)
  SCREEN_HEIGHT=$(echo "$SCREEN_INFO" | cut -d'x' -f2)

  # Get default audio sink monitor for capturing system audio
  DEFAULT_SINK=$(${pkgs.pulseaudio}/bin/pactl get-default-sink 2>/dev/null)
  DEFAULT_MONITOR="''${DEFAULT_SINK}.monitor"

  # Start wf-recorder to capture screen and audio to pipe
  # -y forces overwrite without prompt
  # -g auto captures full screen
  ${pkgs.wf-recorder}/bin/wf-recorder \
    -y \
    -a"$DEFAULT_MONITOR" \
    -f "$FIFO" \
    -r 30 \
    -c libx264 \
    -p crf=28 \
    -p preset=superfast \
    -p tune=zerolatency &
  RECORDER_PID=$!

  # Give wf-recorder a moment to start
  sleep 2

  # Find an available port
  PORT=8080
  while ${pkgs.netcat}/bin/nc -z localhost $PORT 2>/dev/null; do
    PORT=$((PORT + 1))
  done

  # Start ffmpeg to read from FIFO and serve as HTTP with transcoding for chromecast compatibility
  (${pkgs.ffmpeg}/bin/ffmpeg -re -i "$FIFO" \
    -c:v libx264 -preset fast -tune zerolatency \
    -maxrate 8M -bufsize 16M \
    -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    -g 60 \
    -f mp4 \
    -movflags frag_keyframe+empty_moov+default_base_moof+faststart \
    -listen 1 -seekable 0 http://0.0.0.0:$PORT/stream 2>/dev/null) &
  FFMPEG_PID=$!

  # Wait for ffmpeg to start listening
  sleep 3

  # Get local IP
  LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || hostname -I | awk '{print $1}')
  STREAM_URL="http://$LOCAL_IP:$PORT/stream"

  # Create lock file with device name
  echo "$SELECTED_DEVICE" > "$LOCK_FILE"

  # Cast to the device using go-chromecast
  ${pkgs.go-chromecast}/bin/go-chromecast load "$STREAM_URL" -n "$SELECTED_DEVICE" --detach 2>/dev/null &
  CAST_PID=$!

  # Write PIDs to file for cleanup
  echo "$RECORDER_PID $FFMPEG_PID $CAST_PID" > "$PID_FILE"

  # Show notification
  ${pkgs.libnotify}/bin/notify-send -t 5000 "Chromecast" "✓ Casting to $SELECTED_DEVICE\nPress Super+G to stop"
''

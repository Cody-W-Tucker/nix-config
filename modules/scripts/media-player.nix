{ pkgs }:

pkgs.writeShellScriptBin "media-player" ''
  #!/usr/bin/env bash

  # Get the current player status and metadata
  status=$(playerctl status 2>/dev/null)
  spotify_status=$(playerctl -p spotify status 2>/dev/null)
  title=$(playerctl metadata xesam:title 2>/dev/null)

  # Check if playerctl returned any information
  if [ -z "$status" ]; then
    echo '{"icon": "", "text": "No media playing", "class": "custom-media"}'
    exit 0
  fi

  # Format the output
  if [ "$spotify_status" = "Playing" ]; then
    icon=""  # Spotify icon
  elif [ "$status" = "Playing" ]; then
    icon=""
  elif [ "$status" = "Paused" ]; then
    icon=""
  else
    icon=""
  fi

  # Escape double quotes in title for JSON output
  escaped_title=$(echo "$title" | sed 's/"/\\"/g')

  # Output the JSON
  echo "{\"text\": \"$icon\" \"$escaped_title\", \"class\": \"custom-media\"}"
''

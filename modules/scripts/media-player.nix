{ pkgs }:

pkgs.writeShellScriptBin "media-player" ''
  #!/usr/bin/env bash

  # Get the current player status and metadata
  status=$(playerctl status 2>/dev/null)
  artist=$(playerctl metadata xesam:artist 2>/dev/null)
  title=$(playerctl metadata xesam:title 2>/dev/null)

  # Check if playerctl returned any information
  if [ -z "$status" ]; then
    echo '{"icon": "", "text": "No media playing", "class": "custom-media"}'
    exit 0
  fi

  # Format the output
  if [ "$status" = "Playing" ]; then
    icon=""
  elif [ "$status" = "Paused" ]; then
    icon=""
  else
    icon=""
  fi

  # Escape double quotes in artist and title for JSON output
  escaped_artist=$(echo "$artist" | sed 's/"/\\"/g')
  escaped_title=$(echo "$title" | sed 's/"/\\"/g')

  # Output the JSON
  echo "{\"icon\": \"$icon\", \"text\": \"$escaped_artist - $escaped_title\", \"class\": \"custom-media\"}"
''

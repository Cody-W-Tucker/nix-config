{ pkgs }:

pkgs.writeShellScriptBin "waybar-goal" ''
  #!/bin/bash

  # Config
  DATA_FILE="$HOME/.config/waybar/goal_tracker.txt"  # Store progress
  TODAY=$(date +%Y-%m-%d)
  DEFAULT_GOAL=10  # Change this if needed

  # Initialize file if missing
  if [[ ! -f "$DATA_FILE" ]]; then
      echo "$TODAY 0 $DEFAULT_GOAL" > "$DATA_FILE"
  fi

  # Read saved values
  read LAST_DATE COUNT GOAL < "$DATA_FILE"

  # Reset count if a new day starts
  if [[ "$LAST_DATE" != "$TODAY" ]]; then
      COUNT=0
      echo "$TODAY $COUNT $GOAL" > "$DATA_FILE"
  fi

  # Handle interactions
  case "$1" in
      click) ((COUNT++)) ;;  # Increment progress
      scroll-up) ((GOAL++)) ;;  # Increase goal
      scroll-down) ((GOAL > 1)) && ((GOAL--)) ;;  # Decrease goal (min 1)
  esac

  # Save new data
  echo "$TODAY $COUNT $GOAL" > "$DATA_FILE"

  # Output JSON for Waybar
  CLASS="goal-progress"
  [ "$COUNT" -ge "$GOAL" ] && CLASS="goal-achieved"

  echo "{\"text\":\"$COUNT/$GOAL\", \"tooltip\":\"Progress: $COUNT out of $GOAL\", \"class\":\"$CLASS\"}"
''
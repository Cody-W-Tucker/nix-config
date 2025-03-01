{ pkgs }:

pkgs.writeShellScriptBin "waybar-tasks" ''
  #!/bin/bash

  # Fetch task (ID + description) in one query sorted by lowest first
  task_data=$(task +READY -blocked +OVERDUE export | jq -r 'sort_by(.urgency) | .[0] // empty | "\(.id) \(.description)"')

  # Split into ID and description
  task_id=$(echo "$task_data" | awk '{print $1}')
  task_desc=$(echo "$task_data" | cut -d' ' -f2-)

  # Handle completion request
  if [ "$1" == "complete" ]; then
      if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
          task "$task_id" done rc.confirmation=no >/dev/null
      fi
      exit 0
  fi

  # Normal display mode
  if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
      echo "$task_desc"
  else
      echo "No urgent tasks"
  fi
''

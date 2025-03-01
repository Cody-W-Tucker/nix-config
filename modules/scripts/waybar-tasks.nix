{ pkgs }:

pkgs.writeShellScriptBin "waybar-tasks" ''
  #!/bin/bash

  # Get the most urgent task (ID + description) in one query
  task_data=$(task +READY -blocked overdue export | jq -er 'sort_by(.urgency) | reverse | .[0] // empty | "\(.id) \(.description)"')

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

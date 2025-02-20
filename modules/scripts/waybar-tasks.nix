{ pkgs }:

pkgs.writeShellScriptBin "waybar-tasks" ''
  #!/bin/bash

  # Function to fetch the most urgent task
  fetch_task() {
    task +READY -blocked due:today export | jq -r 'sort_by(-.urgency) | .[0] | "\(.id) \(.description)"'
  }

  # Fetch initial task data
  task_data=$(fetch_task)

  # Split into ID and description
  task_id=$(echo "$task_data" | awk '{print $1}')
  task_desc=$(echo "$task_data" | cut -d' ' -f2-)

  # Handle completion request
  if [ "$1" == "complete-and-update" ]; then
      if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
          # Mark the current task as done
          task "$task_id" done rc.confirmation=no >/dev/null

          # Fetch the next task after completing the current one
          task_data=$(fetch_task)
          task_id=$(echo "$task_data" | awk '{print $1}')
          task_desc=$(echo "$task_data" | cut -d' ' -f2-)

          # Immediately update Waybar with the next task
          if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
              echo "$task_desc"
          else
              echo "No urgent tasks"
          fi

          exit 0
      fi
      exit 0
  fi

  # Normal display mode (when no arguments are passed)
  if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
      echo "$task_desc"
  else
      echo "No urgent tasks"
  fi
''

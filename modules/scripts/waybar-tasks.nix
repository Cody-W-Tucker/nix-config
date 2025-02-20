{ pkgs }:

pkgs.writeShellScriptBin "waybar-tasks" ''
  #!/bin/bash

  # Function to fetch the most urgent task (ID + description)
  fetch_task() {
      task_data=$(task +READY -blocked due:today export | jq -r 'sort_by(-.urgency) | .[0] | "\(.id) \(.description)"')
      task_id=$(echo "$task_data" | awk '{print $1}')
      task_desc=$(echo "$task_data" | cut -d' ' -f2-)
  }

  # Handle completion and immediate update
  if [ "$1" == "complete-and-update" ]; then
      # Fetch current task info
      fetch_task

      # Mark current task as done if it exists
      if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
          task "$task_id" done rc.confirmation=no >/dev/null
      fi

      # Fetch the next task after completion
      fetch_task

      # Output the next task or fallback message
      if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
          echo "$task_desc"
      else
          echo "No urgent tasks"
      fi

      exit 0
  fi

  # Normal display mode: fetch and display the most urgent task
  fetch_task

  if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
      echo "$task_desc"
  else
      echo "No urgent tasks"
  fi
''

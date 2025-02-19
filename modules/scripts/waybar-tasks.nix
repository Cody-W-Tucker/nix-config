{ pkgs }:

pkgs.writeShellScriptBin "waybar-tasks" ''
  #!/bin/bash

  # Continuous monitoring loop
  while :; do
    # Get task data
    task_data=$(task +READY -blocked due.before:eow export | jq -r 'sort_by(-.urgency) | .[0] | "\(.id) \(.description)"')
    
    # Split into ID and description
    task_id=$(echo "$task_data" | awk '{print $1}')
    task_desc=$(echo "$task_data" | cut -d' ' -f2-)

    # Output current task
    if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
      echo "$task_desc"
    else
      echo "No urgent tasks"
    fi

    # Wait for task changes
    inotifywait -q -e modify ~/.task/pending.data
  done

  # Completion handler
  if [ "$1" == "complete" ]; then
    if [ "$task_id" != "null" ] && [ -n "$task_id" ]; then
      task "$task_id" done rc.confirmation=no >/dev/null
    fi
    # Restart main loop
    exec "$0"
  fi
''

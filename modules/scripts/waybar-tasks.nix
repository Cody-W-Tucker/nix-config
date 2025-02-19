{ pkgs }:

pkgs.writeShellScriptBin "waybar-tasks" ''
  #!/bin/bash

  # Fetch the most urgent task from Taskwarrior
  task=$(task +READY -blocked export | jq -r 'sort_by(.urgency) | reverse | .[0] | "\(.description)"')

  # Display task or placeholder
  if [ "$task" != "null ()" ]; then
      echo "$task"
  else
      echo "No urgent tasks"
  fi

  # Handle completion when called with 'complete' argument
  if [ "$1" == "complete" ]; then
      task_id=$(task +READY -blocked limit:1 _ids)
      if [ -n "$task_id" ]; then
          task done $task_id
      fi
      # Refresh Waybar
      waybar-signal -r custom/tasks
  fi
''

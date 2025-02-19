{ pkgs }:

pkgs.writeShellScriptBin "taskwarrior-rofi" ''
  #!/usr/bin/env bash

  declare executable_name="taskwarrior-rofi"
  declare notify_command="''${ROFI_TASKWARRIOR_NOTIFICATION:-notify-send}"
  declare task_command="''${ROFI_TASKWARRIOR_PATH:-task}"

  function notify() {
    case $notify_command in
      "rofi")
        rofi -dmenu -l 0 -mesg "''${1}"
        ;;
      "notify-send")
        notify-send -h int:transient:1 -t 3000 "Rofi Taskwarrior" "''${1}" -i "/etc/nixos/modules/icons/taskwarrior.png"
        ;;
    esac
  }

  function quick_add {
    local quickterm=$(rofi -dmenu -l 0 -p 'Add task' -mesg 'Enter task description')
    if [ -n "$quickterm" ]; then
      if $task_command add "$quickterm"; then
        notify 'Task added successfully'
      else
        notify 'Failed to add task'
      fi
    fi
  }

  function complete_task {
    $task_command $1 done && notify 'Task completed successfully'
  }

  function task_menu {
    local action=$(printf "Complete task" | rofi -dmenu -i -l 1 -p 'Action')
    [ "$action" = 'Complete task' ] && complete_task $1
  }

  function list_tasks {
    local filter=""
    [[ -n "$1" ]] && filter="due:today"
    
    declare -A tasks
    while IFS=',' read -r id description; do
      tasks["$description"]="$id"
    done < <($task_command export $filter | jq -r '.[] | "\(.id),\(.description)"' | tr -d '"')

    local selection=$(printf '%s\n' "''${!tasks[@]}" | rofi -dmenu -i -p 'Task')
    [[ -n "$selection" ]] && task_menu "''${tasks[$selection]}"
  }

  function main_menu {
    action=$(printf "List tasks\nToday's tasks" | rofi -dmenu -i -l 2 -p 'Action')
    case "$action" in
      "Today's tasks") list_tasks "today" ;;
      "List tasks") list_tasks ;;
    esac
  }

  if [ "$1" = "quick_add" ]; then
    quick_add
  else
    main_menu
  fi
''

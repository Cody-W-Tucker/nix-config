{ pkgs }:

pkgs.writeShellScriptBin "taskwarrior-rofi" ''
  #!/usr/bin/env bash

  declare executable_name="taskwarrior-rofi"
  declare notify_command="''${ROFI_TASKWARRIOR_NOTIFICATION:-notify-send}"
  declare task_command="''${ROFI_TASKWARRIOR_PATH:-task}"

  function notify() {
    case $notify_command in
      "rofi") rofi -dmenu -l 0 -mesg "''${1}" ;;
      "notify-send") notify-send -h int:transient:1 -t 3000 "Rofi Taskwarrior" "''${1}" i "/etc/nixos/modules/icons/taskwarrior.png" ;;
    esac
  }

  function quick_add {
    local quickterm=$(rofi -dmenu -l 0 -p 'Add task' -mesg 'Enter task (add "due:<date>" for deadlines)')
    [[ -z "$quickterm" ]] && exit 0
    
    # Parse due date if specified
    local description=$(echo "$quickterm" | sed -E 's/ due:[^ ]+//')
    local due_date=$(echo "$quickterm" | grep -oE 'due:[^ ]+' | cut -d: -f2)
    
    local cmd="$task_command add \"$description\""
    [[ -n "$due_date" ]] && cmd+=" due:\"$due_date\""
    
    if eval "$cmd"; then
      notify "Task added successfully"
    else
      notify "Failed to add task"
    fi
  }

  function complete_task {
    local filter="$2"
    $task_command "$1" done && notify "Task completed successfully"
    list_tasks "$filter"  # Refresh list with previous filter
  }

  function task_menu {
    local task_id="$1"
    local filter="$2"
    local action=$(printf "Complete task" | rofi -dmenu -i -l 1 -p 'Action')
    [[ "$action" = 'Complete task' ]] && complete_task "$task_id" "$filter"
  }

  function list_tasks {
    local filter=""
    [[ -n "$1" ]] && filter="due:today"
    
    declare -A tasks
    while IFS=',' read -r id description; do
      tasks["$description"]="$id"
    done < <($task_command export $filter | jq -r '.[] | "\(.id),\(.description)"' | tr -d '"')
    
    local selection=$(printf '%s\n' "''${!tasks[@]}" | rofi -dmenu -i -p 'Task')
    [[ -n "$selection" ]] && task_menu "''${tasks[$selection]}" "$filter"
  }

  function main_menu {
    local action=$(printf "List tasks\nToday's tasks" | rofi -dmenu -i -l 2 -p 'Action')
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

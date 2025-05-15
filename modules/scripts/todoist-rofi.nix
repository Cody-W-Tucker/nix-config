{ pkgs }:

pkgs.writeShellScriptBin "todoist-rofi" ''
  #!/usr/bin/env bash

  declare executable_name="''${todoist-rofi}"

  #   declare notify_command="rofi"
  #   declare notify_command="notify-send"
  declare notify_command="''${ROFI_TODOIST_NOTIFICATION:-notify-send}"

  # Set name of todoist binary
  declare todoist_command="''${ROFI_TODOIST_PATH:-todoist}"

  function notify() {
  	case $notify_command in
  		"rofi")
  			rofi -dmenu -l 0 -mesg "''${1}"
  			;;

  		"notify-send")
  			notify-send -h int:transient:1 -t 3000 "Rofi Todoist" "''${1}" -i "/etc/nixos/modules/icons/todoist.png"
  			;;
  	esac
  }

  function quick_add {
  	local quickterm=`rofi -dmenu -l 0 -p 'Quick add' -mesg 'Enter Quick Add syntax for new task' -theme-str 'imagebox { enabled: false; width: 0px; }'`
  	if [ -z "$quickterm" ]; then
  		exit 0
  	else
  		if $todoist_command quick "$(echo $quickterm)"; then
  			notify 'Task successfully quick added'
  		else
  			notify 'Failed to add task'
  		fi
  	fi
  }

  function complete_task {
  	$todoist_command close $1 && notify 'Task successfully completed'
  }

  function task_menu {
  	local action=`printf "Complete task" | rofi -dmenu -i -l 1 -p 'Pick an action'` 
  	if [ -z "$action" ]; then
  		exit 0
  	fi
  	if [ "$action" = 'Complete task' ]; then
  		complete_task $1;
  	fi
  }

  function list_tasks {
      $todoist_command sync
      
      local filter=""
      [[ -n "$1" ]] && filter="-f $1"
      
      # Read tasks into an associative array
      declare -A tasks
      while IFS=',' read -r id description; do
          tasks["$description"]="$id"
      done < <($todoist_command --csv l $filter | cut -d',' -f 1,6)
      
      # Create a list of descriptions for rofi
      local descriptions=$(printf '%s\n' "''${!tasks[@]}")
      
      # Show rofi menu with descriptions
      local selection=$(echo "$descriptions" | rofi -dmenu -i -p 'Task'   -mesg 'Pick a task:' )
      
      if [[ -n "$selection" ]]; then
          task_menu "''${tasks[$selection]}"
      fi
  }

  function main_menu {
  	action=`printf "List tasks\nToday's tasks" | rofi -dmenu -i -l 2 -p 'Pick an action'`
  	if [ -z "$action" ]; then
  		exit 0
  	fi
  	if [ "$action" = "Today's tasks" ]; then
  		list_tasks "today"
  	fi
  	if [ "$action" = "List tasks" ]; then
  		list_tasks
  	fi
  }

  if [ "''${1}" == "quick_add" ];
  then
  	quick_add
  else
  	main_menu
  fi
''

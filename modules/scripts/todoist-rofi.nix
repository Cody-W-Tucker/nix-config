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
  	local quickterm=`rofi -dmenu -l 0 -p 'Quick add' -mesg 'Enter Quick Add syntax for new task'`
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
  	if [ -n "$1" ]; then
  		local tasklist=`$todoist_command --csv l -f $1 | cut -d',' -f 1,6`
  	else
  		local tasklist=`$todoist_command --csv l | cut -d',' -f 1,6`
  	fi
  	local action=`printf "$tasklist" | rofi -dmenu -i -p 'Task' -mesg 'Pick a task:'|cut -d',' -f1`
  	if [ -z "$action" ]; then
  		exit 0
  	else
  		task_menu $action
  	fi
  }

  function main_menu {
  	action=`printf "List tasks\nToday's tasks" | rofi -dmenu -i -l 7 -p 'Pick an action'`
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

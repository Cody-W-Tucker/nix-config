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

  if [ "''${1}" == "quick_add" ];
  then
  	quick_add
  else
  	exit 0
  fi
''

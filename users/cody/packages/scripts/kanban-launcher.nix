{ pkgs }:

pkgs.writeShellScriptBin "kanban-launcher" ''
    set -euo pipefail

    PROJECT_DIR="$HOME/Projects"
    KANBIN_DIR="/etc/nixos"

    # Function to set kanban title
    set_kanban_title() {
      local state="$1"
      local desc="$2"
      echo -ne "\033]0;[$state] $desc\007"
    }

    # Build project list
    projects="nixos"
    if [ -d "$PROJECT_DIR" ]; then
      for dir in "$PROJECT_DIR"/*/; do
        if [ -d "$dir" ]; then
          projects="$projects\n$(basename "$dir")"
        fi
      done
    fi

    # Select project via rofi
    selected_project=$(echo -e "$projects" | rofi -dmenu -p "Select Project:" -no-custom)
    
    [ -z "$selected_project" ] && exit 0

    # Get task description via rofi
    task_desc=$(rofi -dmenu -p "What to do:")
    
    [ -z "$task_desc" ] && exit 0

    # Determine project directory
    if [ "$selected_project" = "nixos" ]; then
      target_dir="$KANBIN_DIR"
    else
      target_dir="$PROJECT_DIR/$selected_project"
    fi

    # Validate directory exists
    if [ ! -d "$target_dir" ]; then
      notify-send "Error" "Project directory not found: $target_dir"
      exit 1
    fi

    # Create wrapper script for opencode with kanban state management
    wrapper_script=$(mktemp)
    cat > "$wrapper_script" << EOF
  #!/usr/bin/env zsh
  set -euo pipefail

  # Initial state
  printf '\033]0;[INIT] $task_desc\007'
  sleep 0.5

  # Progress state
  printf '\033]0;[PROGRESS] $task_desc\007'

  # Run opencode interactively
  opencode --prompt "$task_desc"
  EXIT_CODE=\$?

  # If opencode succeeds, go to review, otherwise stay
  if [ \$EXIT_CODE -eq 0 ]; then
    printf '\033]0;[REVIEW] $task_desc\007'
    echo ""
    echo "Task complete. Press ENTER to mark as DONE, or Ctrl+C to exit."
    read -r
    printf '\033]0;[DONE] $task_desc\007'
    sleep 2
  else
    printf '\033]0;[REVIEW] $task_desc (failed)\007'
    echo ""
    echo "Task failed. Press ENTER to close or review the output."
    read -r
  fi
  EOF
    chmod +x "$wrapper_script"

    # Launch kitty in the kanban-init workspace with the task
    uwsm app -- kitty --directory "$target_dir" --class kanban-init \
      zsh -l -c "$wrapper_script; rm -f '$wrapper_script'"
''

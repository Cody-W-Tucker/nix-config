{ pkgs }:
pkgs.writeShellApplication {
  name = "opencode-task";
  runtimeInputs = [
    pkgs.jq
    pkgs.zsh
    pkgs.direnv
    pkgs.libnotify
    pkgs.taskwarrior3
  ];
  text = ''
        set -euo pipefail

        PROJECT_DIR="$HOME/Projects"

        # Function to set terminal title for kanban routing
        set_kanban_title() {
          local state="$1"
          local description="$2"
          echo -ne "\033]0;[$state] $description\007"
        }

        task_json=$(task rc.verbose=nothing rc.json.array=on +READY export 2>/dev/null || true)
        if [[ -z "$task_json" ]] || [[ "$task_json" != \[* ]]; then
          notify-send "No ready Taskwarrior tasks."
          exit 1
        fi

        count=$(jq 'length' <<<"$task_json")
        if [[ "$count" -eq 0 ]]; then
          notify-send "No ready Taskwarrior tasks."
          exit 1
        fi

        projects=$(jq -r '.[].project // "default"' <<<"$task_json" | sort -u)

        for project in $projects; do
          project_tasks=$(jq -r --arg p "$project" '[.[] | select(.project // "default" == $p)]' <<<"$task_json")
          task_count=$(jq 'length' <<<"$project_tasks")

          if [[ "$task_count" -eq 0 ]]; then
            continue
          fi

          descriptions=$(jq -r '.[].description' <<<"$project_tasks")
          uuids=$(jq -r '.[].uuid' <<<"$project_tasks")

          if [[ "$project" == "nixos" ]]; then
            target_dir="/etc/nixos"
          elif [[ "$project" == "default" ]]; then
            target_dir="$PWD"
            project=$(basename "$target_dir")
          else
            target_dir="$PROJECT_DIR/$project"
            if [[ ! -d "$target_dir" ]]; then
              if [[ "$(basename "$PWD")" == "$project" ]]; then
                target_dir="$PWD"
              else
                echo "Project directory $target_dir does not exist and doesn't match current dir." >&2
                continue
              fi
            fi
          fi

          if [[ "$task_count" -eq 1 ]]; then
            task_desc="$(echo "$descriptions" | head -1)"
            task_command="Task: $task_desc"
          else
            formatted_descriptions="  - ''${descriptions//''$'\n'/$'\n  - '}"
            task_desc="Tasks for $project ($task_count)"
            task_command="$task_desc:\n$formatted_descriptions"
          fi

          if ! env | grep -q -E '^(PATH|DIRENV|HOME)='; then
            echo "Missing user env vars!"
          fi

          # Set initial kanban state
          set_kanban_title "INIT" "$task_desc"

          escaped_task=$(printf '%q' "$task_command")
          
          # Create a wrapper script that will update the kanban state
          wrapper_script=$(mktemp)
          cat > "$wrapper_script" << 'WRAPPER_EOF'
    #!/usr/bin/env zsh
    set -euo pipefail

    # Function to set terminal title for kanban routing
    set_kanban_title() {
      local state="$1"
      local description="$2"
      echo -ne "\033]0;[$state] $description\007"
    }

    TASK_DESC="''${1:-Task}"

    # Progress state
    set_kanban_title "PROGRESS" "$TASK_DESC"

    # Run the actual task
    ''${2:-echo "No command"}

    # Done state
    set_kanban_title "DONE" "$TASK_DESC"
    WRAPPER_EOF
          chmod +x "$wrapper_script"

          uwsm app -- kitty --directory "$target_dir" \
            zsh -i -c "$wrapper_script '$task_desc' 'opencode run $escaped_task'"

          # Cleanup
          rm -f "$wrapper_script"

          notify-send "Opencode completed: $task_count task(s) for $project"

          while IFS= read -r uuid; do
            task "$uuid" mod status:completed 2>/dev/null || true
          done <<<"$uuids"
        done
  '';
}

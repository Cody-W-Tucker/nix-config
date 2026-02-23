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
        task_command="Task: $(echo "$descriptions" | head -1)"
      else
        formatted_descriptions="  - ''${descriptions//''$'\n'/$'\n  - '}"
        task_command="Tasks for $project ($task_count):\n$formatted_descriptions"
      fi

      if ! env | grep -q -E '^(PATH|DIRENV|HOME)='; then
        echo "❌ Missing user env vars!"
      fi

      escaped_task=$(printf '%q' "$task_command")
      uwsm app -- kitty --directory "$target_dir" \
        zsh -i -c "opencode run $escaped_task"

      notify-send "Opencode completed: $task_count task(s) for $project"

      while IFS= read -r uuid; do
        task "$uuid" mod status:completed 2>/dev/null || true
      done <<<"$uuids"
    done
  '';
}

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
    #!/usr/bin/env zsh

    set -euo pipefail

    PROJECT_DIR="$HOME/Projects"

    task_json=$(task rc.verbose=nothing rc.json.array=off +READY limit:1 export 2>/dev/null || true)
    if [[ -z "$task_json" ]] || [[ "$task_json" != \{* ]]; then
      echo "No ready Taskwarrior tasks." >&2
      exit 1
    fi

    description=$(jq -r '.description // empty' <<<"$task_json")
    id=$(jq -r '.id' <<<"$task_json")
    project=$(jq -r '.project // empty' <<<"$task_json")

    if [[ -n "$project" ]]; then
      if [[ "$project" == "nixos" ]]; then
        target_dir="/etc/nixos"
      else
        target_dir="$PROJECT_DIR/$project"
        if [[ ! -d "$target_dir" ]]; then
          if [[ "$(basename "$PWD")" == "$project" ]]; then
            target_dir="$PWD"
          else
            echo "Project directory $target_dir does not exist and doesn't match current dir." >&2
            exit 1
          fi
        fi
      fi
    else
      target_dir="$PWD"
      project=$(basename "$target_dir")
    fi

    if [[ -z "$project" ]]; then
      project=$(basename "$PWD")
    fi

    task_command="Task: $description"

    if ! env | grep -q -E '^(PATH|DIRENV|HOME)='; then
      echo "❌ Missing user env vars!"
    fi
    uwsm app -- kitty --directory "$target_dir" \
      zsh -i -c "opencode run '$task_command'"
    notify-send "Opencode task completed: $description"
    task "$id" done
  '';
}

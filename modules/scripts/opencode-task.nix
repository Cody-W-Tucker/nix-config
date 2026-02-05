{ pkgs }:
pkgs.writeShellApplication {
  name = "opencode-task";
  runtimeInputs = [
    pkgs.jq
    pkgs.zsh
    pkgs.direnv
    pkgs.taskwarrior
  ];
  text = ''
    #!/usr/bin/env zsh

    set -euo pipefail

    PROJECT_DIR="$HOME/Projects"

    task_json=$(task rc.verbose=nothing rc.json.array=off next limit:1 export 2>/dev/null || true)
    if [[ -z "$task_json" ]] || [[ "$task_json" != \{* ]]; then
      echo "No ready Taskwarrior tasks." >&2
      exit 1
    fi

    description=$(jq -r '.description // empty' <<<"$task_json")
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

    env | grep -E '(PATH|DIRENV|HOME)' || echo "❌ Missing user env vars!"
    uwsm app -- kitty --directory "$target_dir" \
      zsh -i -c "opencode --prompt '$task_command'"
  '';
}

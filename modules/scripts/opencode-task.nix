{ pkgs }:

pkgs.writeShellApplication {
  name = "opencode-task";
  runtimeInputs = [
    pkgs.taskwarrior
    pkgs.jq
  ];
  text = ''
    #!/usr/bin/env bash
    set -euo pipefail

    PROJECT_DIR="$HOME/Projects"

    task_json=$(task rc.verbose=nothing rc.json.array=off +READY limit:1 export 2>/dev/null || true)
    if [[ -z "$task_json" ]] || [[ "$task_json" != \{* ]]; then
      echo "No ready Taskwarrior tasks." >&2
      exit 1
    fi

    description=$(jq -r '.description // empty' <<<"$task_json")
    project=$(jq -r '.project // empty' <<<"$task_json")

    if [[ -z "$description" ]]; then
      echo "Next task is missing a description." >&2
      exit 1
    fi

    if [[ -z "$project" ]]; then
      project=$(basename "$PWD")
    fi

    task_command="Task: $description"

    uwsm app -- kitty --directory "$PROJECT_DIR/$project" \
      zsh -i -c "opencode run '$task_command'"
  '';
}

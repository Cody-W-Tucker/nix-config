{ pkgs }:

pkgs.writeShellScriptBin "opencode-task" ''
  #!/usr/bin/env bash
  set -euo pipefail

  if ! command -v task >/dev/null 2>&1; then
    echo "Taskwarrior is not installed." >&2
    exit 1
  fi

  task_json=$(task rc.verbose=nothing rc.json.array=off +READY limit:1 export 2>/dev/null || true)
  if [[ -z "$task_json" ]] || [[ "$task_json" != \{* ]]; then
    echo "No ready Taskwarrior tasks." >&2
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for opencode-task." >&2
    exit 1
  fi

  description=$(jq -r '.description // empty' <<<"$task_json")
  uuid=$(jq -r '.uuid // empty' <<<"$task_json")
  project=$(jq -r '.project // empty' <<<"$task_json")
  tags=$(jq -r '(.tags // []) | join(", ")' <<<"$task_json")

  if [[ -z "$description" ]]; then
    echo "Next task is missing a description." >&2
    exit 1
  fi

  prompt="Task: $description"
  if [[ -n "$project" ]]; then
    prompt+=$'\n'"Project: $project"
  fi
  if [[ -n "$tags" ]]; then
    prompt+=$'\n'"Tags: $tags"
  fi
  if [[ -n "$uuid" ]]; then
    prompt+=$'\n'"UUID: $uuid"
  fi

  exec opencode --prompt "$prompt" +tab=build "$@"
''

{ pkgs }:

let
  timewarriorHook = pkgs.writeShellScript "taskwarrior-timewarrior-hook" ''
    #!/usr/bin/env bash
    set -euo pipefail

    read -r OLD
    read -r NEW

    if ! command -v jq >/dev/null 2>&1 || ! command -v timew >/dev/null 2>&1; then
      printf '%s\n' "$NEW"
      exit 0
    fi

    old_started=$(jq -r '.start // empty' <<<"$OLD")
    new_started=$(jq -r '.start // empty' <<<"$NEW")

    if [[ -z "$old_started" && -n "$new_started" ]]; then
      uuid=$(jq -r '.uuid // empty' <<<"$NEW")
      project=$(jq -r '.project // empty' <<<"$NEW")
      set -- start
      if [[ -n "$project" ]]; then
        set -- "$@" "project:$project"
      fi
      while IFS= read -r tag; do
        if [[ -n "$tag" ]]; then
          set -- "$@" "$tag"
        fi
      done < <(jq -r '.tags // [] | .[]' <<<"$NEW")
      if [[ -n "$uuid" ]]; then
        set -- "$@" "task:$uuid"
      fi

      timew "$@" >/dev/null 2>&1 || true
    elif [[ -n "$old_started" && -z "$new_started" ]]; then
      timew stop >/dev/null 2>&1 || true
    fi

    printf '%s\n' "$NEW"
  '';

  opencodeHook = pkgs.writeShellScript "taskwarrior-opencode-hook" ''
    #!/usr/bin/env bash
    set -euo pipefail

    read -r OLD
    read -r NEW

    if ! command -v jq >/dev/null 2>&1 || ! command -v opencode >/dev/null 2>&1; then
      printf '%s\n' "$NEW"
      exit 0
    fi

    old_started=$(jq -r '.start // empty' <<<"$OLD")
    new_started=$(jq -r '.start // empty' <<<"$NEW")

    if [[ -z "$old_started" && -n "$new_started" ]]; then
      description=$(jq -r '.description // "Taskwarrior task"' <<<"$NEW")
      project=$(jq -r '.project // empty' <<<"$NEW")
      uuid=$(jq -r '.uuid // empty' <<<"$NEW")

      prompt="Implement: $description"
      if [[ -n "$project" ]]; then
        prompt+=$'\n'"Project: $project"
      fi
      if [[ -n "$uuid" ]]; then
        prompt+=$'\n'"UUID: $uuid"
      fi

      setsid -f opencode --prompt "$prompt" >/dev/null 2>&1 || true
    fi

    printf '%s\n' "$NEW"
  '';
in

{
  timewarriorHook = timewarriorHook;
  opencodeHook = opencodeHook;
}

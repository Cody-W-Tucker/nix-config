{ pkgs }:

pkgs.writeShellScriptBin "find-and-open-file" ''
  #!/usr/bin/env bash

  VAULT="Personal"  # Set your Obsidian vault name here

  # Function to smartly open files
  smart_open() {
    local file="$1"
    if [[ "$file" == *.md ]]; then
      # Remove leading ./ if present
      local file_clean="''${file#./}"
      # URL-encode the file path
      local file_uri
      file_uri=$(jq -rn --arg x "$file_clean" '$x|@uri')
      local uri="obsidian://open?vault=''${VAULT}&file=''${file_uri}"
      xdg-open "$uri"
    else
      xdg-open "$file"
    fi
  }

  # Handle two modes: search-based (with arg) or fuzzy-open (no arg)
  if [ -z "$1" ]; then
    # Mode 1: Fuzzy open any file (no search term)
    selected_file=$(fzf --preview 'bat --style=numbers --color=always {}')
    if [ -n "$selected_file" ]; then
      smart_open "$selected_file"
    else
      echo "No file selected."
    fi
    exit 0
  else
    # Mode 2: Search for files containing "$1"
    selected_file=$(rg --files-with-matches "$1" | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')
    if [ -n "$selected_file" ]; then
      smart_open "$selected_file"
    else
      echo "No file selected."
    fi
  fi
''

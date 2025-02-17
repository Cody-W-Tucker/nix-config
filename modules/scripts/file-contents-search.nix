{ pkgs }:

pkgs.writeShellScriptBin "fif" ''
  #!/bin/bash

  if [ -z "$1" ]; then
    echo "Usage: fif <search_term>"
    exit 1
  fi

  # Use ripgrep (rg) to search for files with matches and fzf for selection
  selected_file=$(rg --files-with-matches "$1" | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')

  # If a file was selected, open it with xdg-open
  if [ -n "$selected_file" ]; then
    xdg-open "$selected_file"
  else
    echo "No file selected."
  fi
''

{ pkgs }:

pkgs.writeShellScriptBin "fif" ''
  #!/bin/bash
  if [ -z "$1" ]; then
    echo "Usage: fif <search_term>"
    exit 1
  fi
  rg --files-with-matches "$1" | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'
''

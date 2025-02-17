{ pkgs }:

pkgs.writeShellScriptBin "fif" ''
  #!/bin/bash
  fif() {
    if [ -z "$1" ]; then
      echo "Usage: fif <search_term>"
      return 1
    fi
    rg --files-with-matches "$1" | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'
  }
''

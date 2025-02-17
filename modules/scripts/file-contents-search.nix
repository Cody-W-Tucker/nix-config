{ pkgs }:

pkgs.writeShellScriptBin {
  name = "fif";
  runtimeInputs = [ pkgs.ripgrep pkgs.fzf pkgs.bat ]; # Ensure dependencies are included
  text = ''
    #!/bin/bash
    if [ -z "$1" ]; then
      echo "Usage: fif <search_term>"
      exit 1
    fi
    rg --files-with-matches "$1" | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'
  '';
}

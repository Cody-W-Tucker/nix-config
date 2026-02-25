{ pkgs }:

pkgs.writeShellScriptBin "fastUpdate" ''
  cd /etc/nixos &&
  nix fmt &&
  git add . &&
  if [ -z "$1" ]; then
    echo "Enter commit message:" &&
    read commit_message
    commit_message=''${commit_message:-"Fast update NixOS configuration"}
  else
    commit_message="$1"
  fi &&
  git commit -m "$commit_message" &&
  sudo nixos-rebuild switch --fast
''

{ pkgs }:

pkgs.writeShellScriptBin "update" ''
  cd /etc/nixos &&
  git add . &&
  if [ -z "$1" ]; then
    echo "Enter commit message:" &&
    read commit_message
    commit_message=''${commit_message:-"Update NixOS configuration"}
  else
    commit_message="$1"
  fi &&
  git commit -m "$commit_message" &&
  sudo nixos-rebuild switch &&
  git push
''

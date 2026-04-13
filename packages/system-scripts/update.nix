{ pkgs }:

let
  checkImports = pkgs.callPackage ./check-imports.nix { };
in
pkgs.writeShellApplication {
  name = "update";
  runtimeInputs = [
    pkgs.nix
    pkgs.git
    pkgs.sudo
    pkgs.nixos-rebuild
    checkImports
  ];
  text = ''
    set -euo pipefail

    cd /etc/nixos
    nix fmt

    # Check for unimported .nix files
    check-imports

    git add .
    if [ -z "''${1-}" ]; then
      echo "Enter commit message:"
      read -r commit_message
      commit_message=''${commit_message:-"Update NixOS configuration"}
    else
      commit_message="$1"
    fi

    git commit -m "$commit_message"
    sudo nixos-rebuild switch
    git push
  '';
}

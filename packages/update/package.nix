{
  writeShellApplication,
  nix,
  git,
  nixos-rebuild,
  check-imports,
}:

writeShellApplication {
  name = "update";
  runtimeInputs = [
    nix
    git
    nixos-rebuild
    check-imports
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

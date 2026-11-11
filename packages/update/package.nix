{
  writeShellApplication,
  nix,
  git,
  nixos-rebuild,
  check-imports,
  openssh,
}:

writeShellApplication {
  name = "update";
  runtimeInputs = [
    nix
    git
    nixos-rebuild
    check-imports
    openssh
  ];
  text = ''
    set -euo pipefail

    # Usage: update [--nas] [commit message]
    #   --nas  after switching this host, pull and switch the NAS too.
    deploy_nas=false
    if [ "''${1-}" = "--nas" ]; then
      deploy_nas=true
      shift
    fi

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

    if [ "$deploy_nas" = true ]; then
      # The NAS evaluates and builds itself (wired, more RAM); -t lets its
      # sudo prompt for a password. Refuse to touch a NAS checkout with
      # uncommitted work; --ff-only refuses to merge unpushed NAS commits.
      # shellcheck disable=SC2016 # expanded on the NAS, not here
      ssh -t nas 'cd /etc/nixos &&
        if [ -n "$(git status --porcelain)" ]; then
          echo "NAS /etc/nixos has uncommitted changes; not deploying:" >&2
          git status --short >&2
          exit 1
        fi &&
        git pull --ff-only && sudo nixos-rebuild switch'
    fi
  '';
}

{
  writeShellApplication,
  nix,
  git,
  nixos-rebuild,
  openssh,
}:

writeShellApplication {
  name = "update";
  runtimeInputs = [
    nix
    git
    nixos-rebuild
    openssh
  ];
  text = ''
    set -euo pipefail

    deploy_nas=false
    if [ "''${1-}" = "--nas" ]; then
      deploy_nas=true
      shift
    fi
    if [ "$#" -ne 0 ]; then
      echo "Usage: update [--nas]" >&2
      exit 2
    fi

    cd /etc/nixos

    if [ -n "$(git status --porcelain)" ]; then
      echo "/etc/nixos has uncommitted changes. Have an agent commit them, then run update again:" >&2
      git status --short >&2
      exit 1
    fi

    branch=$(git symbolic-ref --short HEAD)
    if [ "$branch" != main ]; then
      echo "/etc/nixos is on $branch, not main." >&2
      exit 1
    fi

    git pull --rebase

    sudo nixos-rebuild switch

    if [ -n "$(git rev-list '@{upstream}..HEAD')" ]; then
      git push
    fi

    if [ "$deploy_nas" = true ]; then
      # shellcheck disable=SC2016
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

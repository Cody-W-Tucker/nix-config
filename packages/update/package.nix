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
    check-imports

    # Stage first so flakes can see new files. A failed build leaves the
    # changes staged, but does not commit, activate, or push anything.
    git add .

    # Evaluate AND realise both closures before publishing: a successful switch
    # on this machine alone says nothing about the other host's build.
    nix build --no-link --keep-going --print-build-logs \
      .#nixosConfigurations.beast.config.system.build.toplevel \
      .#nixosConfigurations.nas.config.system.build.toplevel

    # Keep the NAS runtime closure available on Beast across garbage collection.
    # This second build reuses the successful result above and only creates a root.
    if [ "$(< /proc/sys/kernel/hostname)" = beast ]; then
      root_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/codyos"
      mkdir -p "$root_dir"
      nix build --out-link "$root_dir/nas-system" \
        .#nixosConfigurations.nas.config.system.build.toplevel
    fi

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
      # The NAS rebuilds itself (normally now a cache hit) after the push. Refuse
      # to touch a checkout with uncommitted work or merge unpushed NAS commits.
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

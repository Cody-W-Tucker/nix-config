set -euo pipefail

# Usage: update [--nas] [commit message]
#   --nas  after switching this host, pull and switch the NAS too.
deploy_nas=false
if [ "${1-}" = "--nas" ]; then
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

if [ -z "${1-}" ]; then
  echo "Enter commit message:"
  read -r commit_message
  commit_message=${commit_message:-"Update NixOS configuration"}
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

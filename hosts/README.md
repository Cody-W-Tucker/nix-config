# Host Instructions

This directory holds host-specific system definitions.

## Adding A New Host

Install via the NixOS installer and configure disks well enough to build a default config. Then prepare the machine so it can join this shared system.

1. Boot the machine with the NixOS installer and partition / mount disks.
2. Edit `/mnt/etc/nixos/configuration.nix` just enough to bootstrap the machine:
   1. Enable SSH
   2. Install Git
   3. Install Kitty so the system clipboard works as expected
   4. Set the hostname
3. Rebuild the machine so it picks up the new hostname and packages.
4. Copy your SSH key to the machine with `ssh-copy-id` and connect over SSH.
5. Clone the main repo to `/etc/nixos` on the new machine.
6. Move the generated machine config aside to `/etc/nixos-aside`.
7. Copy the generated hardware / disk details from `/etc/nixos-aside` into a new file under `hosts/` that matches the existing host pattern.
8. Commit and push the host definition from the parent machine so the main repo stays authoritative.
9. Pull the updated main repo on the new machine before the first real rebuild or install.

## Secrets Setup

After the host exists in the repo, grant it access to secrets in the private `nixos-secrets` repo before the first real install / rebuild.

1. Collect the new machine's host SSH public key.
2. Add that host to `.sops.yaml` in the private repo.
3. Re-encrypt the secret files the new host should be able to read.
4. Add any host-specific secrets the machine needs.
5. Push the private repo changes.

## First Real Build

The main flake fetches the private secrets repo from GitHub. A fresh machine cannot read the token from `sops` until after the first successful activation, so the first real build needs a one-shot GitHub token bootstrap.

1. Create a fine-grained GitHub token with read-only access to `Cody-W-Tucker/nixos-secrets`.
2. Pull the latest main repo on the new machine so `flake.nix` and `flake.lock` both point at `github:Cody-W-Tucker/nixos-secrets`.
3. Run the first real rebuild or install with a one-shot token:

```bash
read -s GITHUB_TOKEN
sudo nixos-rebuild switch \
  --flake /etc/nixos#<host> \
  --option access-tokens "github.com=$GITHUB_TOKEN"
unset GITHUB_TOKEN
```

4. After that first successful activation, normal rebuilds should work without passing the token on the command line because the system renders the token-backed Nix config from `sops`.

## Notes

The current host pattern appears to inline hardware details into the host file instead of relying on a separate `hardware-configuration.nix`. If that stops being useful, splitting hardware back out would make regeneration easier when the machine changes.

The first build will fail if the host is not already included in the private repo's `.sops.yaml` recipients or if `flake.lock` still pins `nixos-secrets` to an old SSH URL.

# Installing a new machine

A new machine joins as a Den host: a host file and a hardware file in `modules/hosts/`, committed from an existing machine, plus a recipient entry in the private `nixos-secrets` repo.

## 1. Bootstrap from the installer

1. Boot the NixOS installer. Partition and mount the disks.
2. Edit `/mnt/etc/nixos/configuration.nix` just enough to join: enable SSH, install Git and Kitty (for the clipboard over SSH), set the hostname.
3. Install and reboot.
4. From beast, run `ssh-copy-id <host>`, then connect.

## 2. Declare the host

1. On the new machine, clone the repo to `/etc/nixos`. Move the generated config aside to `/etc/nixos-aside` first.
2. Copy the hardware details from `/etc/nixos-aside` to `modules/hosts/_<host>-hardware.nix`.
3. Create `modules/hosts/<host>.nix` from [`beast.nix`](../../modules/hosts/beast.nix) or [`nas.nix`](../../modules/hosts/nas.nix):
   - `den.hosts.x86_64-linux.<host>`: `channel` (`"stable"` or `"unstable"`), `users.codyt = { }`, `lan`, `tailscale`.
   - `den.aspects.<host>`: `includes`, `provides.to-users.homeManager.home.stateVersion`, and a `nixos` block that imports the hardware file and sets `networking.hostName`.
4. Commit and push the two files **from beast**, so the main repo stays the source of truth. Then pull on the new machine.

## 3. Give it access to secrets

1. On the new machine, print the age recipient of its SSH host key:

   ```bash
   nix shell nixpkgs#ssh-to-age --command sh -c 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
   ```

2. In `nixos-secrets`, add the recipient to `.sops.yaml`. Run `sops updatekeys` on each file the host must read. Add any host-only secrets. Push.
3. In `/etc/nixos`, run `nix flake update nixos-secrets`, commit and push from beast, and pull on the new machine.

Without this step the build succeeds, but services that need secrets fail to start.

## 4. First build

The flake fetches two private repos: `nixos-secrets` and `runtime` (the `workflow` input). The machine reads its GitHub token from sops only after its first activation, so pass a fine-grained, read-only token for both repos once:

```bash
read -s GITHUB_TOKEN
sudo nixos-rebuild switch --flake /etc/nixos#<host> \
  --option access-tokens "github.com=$GITHUB_TOKEN"
unset GITHUB_TOKEN
```

After this activation, `update` works without a token ([Building and updating](getting-started.md)). If the build stops while fetching `nixos-secrets`, the token is missing or `flake.lock` still points at an old SSH URL.

## 5. Join the rest of the system

1. Run `sudo tailscale up`. Put the Tailscale address in the host file.
2. Run `gh auth login` and `deja embed`.
3. To sync `Share`, add the machine's Syncthing device ID to `devices` in [`syncthing.nix`](../../modules/file-sharing/syncthing.nix).
4. The nightly cache build and nixd's option completion know `beast` and `nas` by name. To include the new host, add it in [`nightly-build.nix`](../../modules/nix/nightly-build.nix) and [`_plugins/lsp.nix`](../../modules/editor/_plugins/lsp.nix).

## Changing it

| To change                               | Edit                                                                           |
| --------------------------------------- | ------------------------------------------------------------------------------ |
| The host's features and facts           | `modules/hosts/<host>.nix`                                                     |
| Hardware                                | `modules/hosts/_<host>-hardware.nix` (regenerate with `nixos-generate-config`) |
| Channel → nixpkgs, Home Manager, nixvim | [`channels.nix`](../../modules/hosts/channels.nix)                             |

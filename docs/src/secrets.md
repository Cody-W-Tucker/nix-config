# Secrets

Secret values live encrypted in the private `nixos-secrets` repository, a locked flake input of this repo. Each host decrypts, at switch time, only the secrets that its included aspects declare.

## Add or change a secret

1. Edit the file yourself with `sops`, then ask an agent to commit it. Agents write every commit message; never commit or push by hand.
2. Ask an agent to run `nix flake update nixos-secrets` in `/etc/nixos` and commit the lock change. Until then, the pushed value does not reach any host.
3. Declare the secret in the file of the service that uses it, with a quoted name: `sops.secrets."paperless-password" = { owner = "paperless"; };`. Use `sops.templates` for files that mix secrets and settings.
4. Run `update`. It pulls `main`, switches beast, and pushes the commit, and refuses while the tree has uncommitted changes.

## Add a host

A new host decrypts only after its SSH host key is a recipient. Its first build also needs a GitHub token passed by hand, because the token that fetches the private inputs (`github-nix-secrets-read`) is itself a secret. See [Installing a new machine](new-machine.md#3-give-it-access-to-secrets). GitHub Actions uses the `NIX_SECRETS_READ` repository secret for the same access.

## Changing it

| To change | Edit |
| --- | --- |
| sops-nix setup on every host | [`secrets.nix`](../../modules/secrets.nix) |
| A service's secrets | That service's own file. Multi-value example: [`_nixos/secrets/default.nix`](../../modules/ai/hermes-agent/_nixos/secrets/default.nix) |

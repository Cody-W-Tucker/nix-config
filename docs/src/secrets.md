# Secrets

Secret values live encrypted in the private `nixos-secrets` repository, a locked flake input of this repo. Each host decrypts, at switch time, only the secrets that its included aspects declare.

## Add or change a secret

1. In your `nixos-secrets` checkout, edit the file with `sops`. Commit and push it yourself. Agents do not do this step.
2. Tell an agent the secret is pushed. It runs `nix flake update nixos-secrets` in `/etc/nixos` and commits the lock. Until then, the pushed value does not reach any host.
3. For a new secret, the agent also declares it in the file of the service that uses it, with a quoted name: `sops.secrets."paperless-password" = { owner = "paperless"; };`. Files that mix secrets and settings use `sops.templates`.
4. Run `update`.

## Add a host

A new host decrypts only after its SSH host key is a recipient. Its first build also needs a GitHub token passed by hand, because the token that fetches the private inputs (`github-nix-secrets-read`) is itself a secret. See [Installing a new machine](new-machine.md#3-give-it-access-to-secrets). GitHub Actions uses the `NIX_SECRETS_READ` repository secret for the same access.

## Changing it

| To change | Edit |
| --- | --- |
| sops-nix setup on every host | [`secrets.nix`](../../modules/secrets.nix) |
| A service's secrets | That service's own file. Multi-value example: [`_nixos/secrets/default.nix`](../../modules/ai/hermes-agent/_nixos/secrets/default.nix) |

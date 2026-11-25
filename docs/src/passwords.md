# Passwords (Vaultwarden)

Vaultwarden on the NAS, at [vault.homehub.tv](https://vault.homehub.tv), is a password server for the official Bitwarden apps and browser extensions. It is reachable at home or over Tailscale.

## Set it up once

1. On any host, run `nix shell nixpkgs#vaultwarden --command vaultwarden hash`.
2. Type a long admin token twice. Save the token in a safe place.
3. Copy the `$argon2id$...` line that it prints.
4. In your `nixos-secrets` checkout, run `sops edit secrets/secrets.yaml`.
5. Add `vaultwarden-admin-token: '<the $argon2id$ line>'`. Use single quotes.
6. Commit and push, then follow [Secrets](secrets.md#add-or-change-a-secret) to update the lock and run `update`.

Add the key before the first `update` that includes Vaultwarden. Without it, the NAS build stops with `the key 'vaultwarden-admin-token' cannot be found`.

## Make an account

Sign-ups are closed. Nothing sends email.

1. Open [vault.homehub.tv/admin](https://vault.homehub.tv/admin) and enter the admin token.
2. Under _Users_, invite your email address. No email arrives.
3. Open [vault.homehub.tv](https://vault.homehub.tv) and create an account with that address.

## Connect the apps

On the Bitwarden login screen, set _Logging in on_ to _self-hosted_. Enter `https://vault.homehub.tv` as the server URL.

Away from home without Tailscale, the apps cannot sync. They still show the vault from their last sync.

Changes from another device appear on a phone after the next sync, not at once. Pull down in the vault list to sync now.

## Move from Bitwarden cloud

1. In the Bitwarden web vault, use _Tools_ → _Export vault_ as `.json`.
2. In [vault.homehub.tv](https://vault.homehub.tv), use _Tools_ → _Import data_ with that file.
3. Delete the export file.

The export does not contain attachments. Download them from the cloud vault and attach them again.

## Wrong passwords

Five failed logins, admin tokens or two-step codes from one address within 10 minutes block that address from the NAS's web apps for 24 hours. Repeat blocks last longer. Addresses on the home LAN are never blocked. Over Tailscale they are.

To lift a block, run `sudo fail2ban-client set vaultwarden unbanip <address>` on the NAS.

## Backups

The vault database, keys, attachments and Sends are in the nightly Restic backup. To restore the database, follow [Bring back an app database](backups.md#bring-back-an-app-database) with the app name `vaultwarden` and the owner `vaultwarden:vaultwarden`.

## Changing it

| To change | Edit |
| --- | --- |
| Address, sign-ups, upload size, blocking, backup paths | [`vaultwarden.nix`](../../modules/web/vaultwarden.nix) |
| How many failures block, and for how long | [`networking.nix`](../../modules/networking/networking.nix) |

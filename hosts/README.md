# Host Instructions

This directory holds host-specific system definitions.

## Adding A New Host

Install via the NixOS installer and configure disks well enough to build a default config. Then prepare the machine so it can join this shared system.

1. Edit `configuration.nix` on the new machine to:
   1. Enable SSH
   2. Install Git
   3. Install Kitty so the system clipboard works as expected
   4. Set the hostname
2. Rebuild the config with the new hostname and connect over SSH.
3. Copy your SSH key to the machine with `ssh-copy-id`.
4. Copy the current repo to the new machine home directory.
5. Move the generated machine config aside to `/etc/nixos-aside`.
6. Move this repo into place at `/etc/nixos`.
7. Copy the new machine's generated config from `nixos-aside` into `hosts/`.
8. Commit and push from the parent machine so the host definition work stays in the main repo.
9. Fold the generated hardware and configuration details into a host file that matches the existing host pattern, and make sure the drive configuration is correct.
10. Commit the host change, pull on the child machine, and rebuild there.

## Secrets Setup

After the host exists in the repo, grant it access to secrets.

1. Create a public key for the new machine using the SOPS-Nix setup flow.
2. Add the public key to `.sops.yaml`.
3. Run `sops updatekeys secrets.yaml`.

## Notes

The current host pattern appears to inline hardware details into the host file instead of relying on a separate `hardware-configuration.nix`. If that stops being useful, splitting hardware back out would make regeneration easier when the machine changes.

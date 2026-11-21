# Host Instructions

This directory holds host-specific system definitions: `<host>.nix` (Den host entry, feature list, machine facts), `_<host>-hardware.nix` (disks, initrd/kernel modules, device quirks) and `<host>.md` (hardware and storage notes).

Hardware is kept separate from host policy so it can be regenerated with `nixos-generate-config` without touching policy.

To add a machine, follow [Installing a new machine](../../docs/src/new-machine.md): installer bootstrap, host declaration, `nixos-secrets` recipients, and the first build with a one-shot GitHub token.

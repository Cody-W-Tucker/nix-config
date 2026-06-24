# User Profiles

Owns Home Manager profiles and the glue that exposes them to hosts.

Does not own system services, hardware, networking, or host composition. Those belong in `modules/` or `hosts/`.

## Placement Rules

- Put account defaults in the user's `core.nix`.
- Put role behavior in `desktop.nix`, `server.nix`, or a role subdirectory.
- Keep GUI apps and desktop tools under the desktop role, not in core.
- Do not hide NixOS services here unless Home Manager is the real owner.
- Add new users as their own directory instead of special-casing Cody paths.

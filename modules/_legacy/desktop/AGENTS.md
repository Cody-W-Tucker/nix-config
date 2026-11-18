# System Desktop Modules

Owns reusable system-level desktop plumbing.

Does not own Cody's Home Manager apps, editor settings, dotfiles, or user packages. Put those under `users/cody/desktop`.

## Placement Rules

- Put display, audio, printing, VPN, hardware, portals, logging, and desktop services here.
- Keep app preferences and user-facing packages in Home Manager.
- Keep host-specific hardware quirks in `hosts/` unless they are reusable.
- Split focused desktop services into named files or subdirectories instead of growing one module.
- Treat groups, udev, systemd, and daemon changes as system concerns owned here.

# Cody Home Manager Profile

Owns Cody's user-level configuration across roles.

Does not own host facts, NixOS services, or desktop-only behavior that already has a narrower home under `desktop/`.

## Placement Rules

- Use `core.nix` only for settings useful on both desktop and server.
- Use `desktop.nix` and `desktop/` for GUI apps, Hyprland, Obsidian, local tools, and desktop packages.
- Use `server.nix` for server-session Home Manager behavior.
- Keep generated or app-owned state out of Nix unless it captures durable intent.
- Prefer extending an existing role file before adding another top-level Cody file.

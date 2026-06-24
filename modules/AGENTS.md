# Reusable NixOS Modules

Owns system-level NixOS behavior that hosts compose.

Does not own one-host facts or Home Manager/user preferences. Put those in `hosts/` or `users/`.

## Placement Rules

- Keep reusable services, system defaults, server stacks, and desktop plumbing here.
- Keep host-specific choices in `hosts/`.
- Keep user app configuration in `users/`, even when it supports a system service.
- Put custom service integrations under `services/<name>/default.nix` once they grow past one file.
- Keep `default.nix` files as assembly spines; split scripts, packages, patches, and runtime wiring into named files.
- Declare secrets close to the consuming service, with quoted names for dashed keys.

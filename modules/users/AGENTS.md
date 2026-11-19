# User Profiles

Owns the `codyt` user: the Den user aspect (`codyt.nix`, account + Home Manager profile; editor in `modules/editor/`, AI harness in `modules/harness/`, shell/git/CLI tools in `modules/shell/`).

Does not own system services, hardware, networking, or host composition. Those belong in `modules/` or `modules/hosts/`.

## Placement Rules

- Settings useful on every host go in an aspect under `modules/users/` that `codyt.nix` includes.
- GUI apps and desktop tools belong to the desktop aspects in `modules/desktop/`, not here.
- Host-specific user content is delivered by that host's aspects through `provides.to-users.homeManager` (e.g. `modules/hosts/<host>.nix`, `modules/desktop/*`, `den.aspects.opencode.remote`); `inputs` comes from `extraSpecialArgs` in `modules/users/home-manager.nix`, host facts (`channel`, `localAi`, `hardwareConfig`) are read from `host` in the aspect.
- Do not hide NixOS services here unless Home Manager is the real owner.
- Keep generated or app-owned state out of Nix unless it captures durable intent.
- Add new users as their own aspect instead of special-casing Cody paths.

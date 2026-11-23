# User Profiles

Owns the `codyt` user: the Den user aspect (`codyt.nix`, account + Home Manager profile; editor in `modules/editor/`, AI harness in `modules/harness/`, shell/git/CLI tools in `modules/shell/`).

Does not own system services, hardware, networking, or host composition. Those belong in `modules/` or `modules/hosts/`.

## Placement Rules

- Settings useful on every host go in an aspect under `modules/users/` that `codyt.nix` includes; a feature that belongs on every host registers itself in `den.default.includes` in its own file (shell, git, nixvim, harness).
- GUI apps and desktop tools belong to the `graphical` and `apps` aspects (`modules/graphical/`, `modules/apps/`), not here.
- Host-specific user content comes from the owning feature's `provides.to-users.homeManager` contribution (e.g. `graphical`, `apps`, `opencode.remote`). The host file uses the same route for `home.stateVersion`. `inputs` comes from `extraSpecialArgs` in `modules/users/home-manager.nix`; request Den's `host` argument only when the aspect uses host facts such as `channel`, `localAi`, or `hardwareConfig`.
- Do not hide NixOS services here unless Home Manager is the real owner.
- Keep generated or app-owned state out of Nix unless it captures durable intent.
- Add new users as their own aspect instead of special-casing Cody paths.

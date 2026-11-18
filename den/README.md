# den/

[Den](https://github.com/denful/den) (pinned in `flake.nix`) owns `nixosConfigurations`. Everything in this directory is a flake-level module (not a NixOS module), loaded by `import-tree` from `flake.nix`. Do not add a `default.nix` here and never point `import-tree` at `modules/`.

| Path | Owns |
| --- | --- |
| `hosts.nix` | `den.hosts` instantiation: which `nixosSystem` each host uses (`beast` on `nixpkgs-unstable`, `nas` on stable `nixpkgs`) and the `inputs`/`self` specialArgs. |
| `hosts/<host>.nix` | The host aspect: which role/feature aspects it includes, which Home Manager NixOS module it pairs with, `home-manager.extraSpecialArgs`, and the Home Manager user imports (including the nixvim and nixos-secrets modules). |
| `aspects/base.nix` | Shared baseline (`modules/system/base.nix`, `modules/hardware/baseline.nix`). |
| `aspects/desktop.nix`, `aspects/nas-role.nix` | Role profiles (`modules/desktop`; `modules/nas` plus workflow and vpn-confinement). |
| `aspects/hermes-agent.nix` | NixOS-side Hermes backup wiring (nas only). |
| `aspects/features.nix` | Pure `codyos.<name>.enable` gates as includable aspects. |

`hosts/<host>/` keeps machine facts only: hardware imports, mounts, networking, `stateVersion`, and option-carrying `codyos.*` settings.

## Rules that keep the build identical

- The stable/unstable pairing is chosen per host in `den/hosts.nix` and `den/hosts/<host>.nix`: beast uses `nixpkgs-unstable` + `home-manager` + `nixvim`; nas uses `nixpkgs` + `home-manager-stable` + `nixvim-stable`. The HM-version sniffs in `users/cody/harness/` rely on this.
- Host aspect names must equal the `den.hosts` names (`beast`, `nas`), and those are also the `nixosConfigurations` names used by `update`, the nightly build and `lsp.nix`.
- Home Manager is still wired by hand (not Den's HM battery, no den users). User module `imports` order affects `home.packages` order and so the derivation; keep all user imports for a host in one list.
- Per-host data that Home Manager needs is a host attribute bridged to `home-manager.extraSpecialArgs` (e.g. `hardwareConfig` on beast).

## Adding a host

1. Add `hosts/<name>/default.nix` and `hardware-configuration.nix` (machine facts only).
2. Add `den.hosts.x86_64-linux.<name>.instantiate` in `den/hosts.nix` (pick the nixpkgs channel).
3. Add `den/hosts/<name>.nix` with `den.aspects.<name>`: `includes` for the roles/features, and a `nixos` module importing the matching Home Manager NixOS module and `../../hosts/<name>`, plus the Home Manager user wiring.
4. `git add` the new files, then check `nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`.

## Adding an aspect

Create `den/aspects/<name>.nix` with `den.aspects.<name>.nixos = { ... };` (a NixOS module; a function form gets `config`), then add `den.aspects.<name>` to a host aspect's `includes`. Leaf service modules stay plain NixOS/Home Manager modules under `modules/` and `users/`; an aspect imports them.

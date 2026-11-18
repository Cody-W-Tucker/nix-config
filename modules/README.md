# modules/ (Den tree; transitional)

[Den](https://github.com/denful/den) (pinned in `flake.nix`) owns `nixosConfigurations`. Everything in this directory is a flake-level module (not a NixOS module), loaded by `import-tree` from `flake.nix`. `import-tree ./modules` skips every path containing `/_`, so the old NixOS/Home Manager module tree lives in `_legacy/` (not loaded by import-tree; aspects import it explicitly) until later slices convert it. Never leave a NixOS/HM module at a non-underscore path, and do not add a `default.nix` outside `_` paths. Target layout: [`docs/Den-Native-Layout.md`](../docs/Den-Native-Layout.md).

| Path | Owns |
| --- | --- |
| `hosts/_instantiate.nix` | Shared `nixosSystem` wrapper (plain function, not a Den module): adds `system` and the `inputs`/`self` specialArgs. |
| `hosts/<host>.nix` | The whole host: `den.hosts` entry (`instantiate` channel, `channel`, `lan`, `tailscale`, `mac`, `hardwareConfig`) and `den.aspects.<host>` (role/feature includes, machine facts in its `nixos` block, the Home Manager pairing and user imports). `hosts/_<host>-hardware.nix` and `_nas-models.nix` are imported by it. |
| `roles/base.nix` | Shared baseline (`_legacy/system/base.nix`, `_legacy/hardware/baseline.nix`) and `codyos.site.hosts`, populated from the den host attributes. |
| `roles/desktop.nix`, `roles/nas-role.nix` | Role profiles (`_legacy/desktop`; `_legacy/nas` plus workflow and vpn-confinement). |
| `roles/hermes-agent.nix` | NixOS-side Hermes backup wiring (nas only). |
| `roles/features.nix` | Pure `codyos.<name>.enable` gates as includable aspects. |

Machine facts (hardware import, mounts, networking, `stateVersion`, option-carrying `codyos.*` settings) live in the host aspect's `nixos` block in `hosts/<host>.nix`.

## Rules that keep the build identical

- The stable/unstable pairing is chosen per host in `modules/hosts/<host>.nix` (`instantiate`, `channel`) and `modules/hosts/<host>.nix`: beast uses `nixpkgs-unstable` + `home-manager` + `nixvim`; nas uses `nixpkgs` + `home-manager-stable` + `nixvim-stable`. The HM-version sniffs in `_legacy/users/cody/harness/` rely on this.
- Host aspect names must equal the `den.hosts` names (`beast`, `nas`), and those are also the `nixosConfigurations` names used by `update`, the nightly build and `lsp.nix`.
- Home Manager is still wired by hand (not Den's HM battery, no den users). User module `imports` order affects `home.packages` order and so the derivation; keep all user imports for a host in one list.
- Per-host data that Home Manager needs is a host attribute bridged to `home-manager.extraSpecialArgs` (e.g. `hardwareConfig` on beast).

## Adding a host

1. Add `hosts/_<name>-hardware.nix` (generated hardware config).
2. In `hosts/<name>.nix` declare `den.hosts.x86_64-linux.<name>` with `instantiate = mkInstantiate <nixpkgs channel>.lib.nixosSystem` (see an existing host), `channel`, `lan`, `tailscale` (and `mac`).
3. In the same file add `den.aspects.<name>`: `includes` for the roles/features, and a `nixos` module importing the matching Home Manager NixOS module and `./_<name>-hardware.nix`, holding the machine facts, plus the Home Manager user wiring.
4. `git add` the new files, then check `nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`.

## Adding an aspect

Create `roles/<name>.nix` with `den.aspects.<name>.nixos = { ... };` (a NixOS module; a function form gets `config`), then add `den.aspects.<name>` to a host aspect's `includes`. Leaf service modules stay plain NixOS/Home Manager modules under `_legacy/`; an aspect imports them.

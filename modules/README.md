# modules/ (Den tree)

[Den](https://github.com/denful/den) (pinned in `flake.nix`) owns `nixosConfigurations`. Everything in this directory is a flake-level module (not a NixOS module), loaded by `import-tree` from `flake.nix`. `import-tree ./modules` skips every path containing `/_`, supporting NixOS/Home Manager modules live under `_` names and are imported explicitly by their aspects. Never leave a NixOS/HM module at a non-underscore path, and do not add a `default.nix` outside `_` paths. Target layout: [`docs/Den-Native-Layout.md`](../docs/Den-Native-Layout.md).

| Path | Owns |
| --- | --- |
| `hosts/_instantiate.nix` | Shared `nixosSystem` wrapper (plain function, not a Den module): adds `system` and the `inputs`/`self` specialArgs. |
| `hosts/<host>.nix` | The whole host: `den.hosts` entry (`instantiate` channel, `channel`, `lan`, `tailscale`, `mac`, `hardwareConfig`) and `den.aspects.<host>` (role/feature includes, machine facts in its `nixos` block, the Home Manager pairing and user imports). `hosts/_<host>-hardware.nix` and `_nas-models.nix` are imported by it. |
| `base/base.nix`, `base/*.nix` | The `base` aspect and one aspect per concern it includes (nix, locale, networking, logging, shell, packages, scripts, overlays, sops, accounts, core-services, site, home-manager). `base/site.nix` declares `codyos.site` and fills `codyos.site.hosts` from the den host attributes. |
| `hardware/*.nix` | `hardware-baseline` (included by base) and `nvidia` (included by hosts with an NVIDIA GPU; `nvidiaPowerLimit` host attribute = nvidia-smi power cap in watts, nas only). |
| `users/codyt.nix` | The codyt aspect: `user` class (account, forwarded to `users.users.codyt`) and `homeManager`. |
| `desktop/desktop.nix`, `server/server.nix` | Role profiles: `desktop` and `server` include the per-feature / per-service aspects in their directories (server also imports the workflow and vpn-confinement NixOS modules). |

Machine facts (hardware import, mounts, networking, `stateVersion`, option-carrying `codyos.*` settings) live in the host aspect's `nixos` block in `hosts/<host>.nix`.

## Rules that keep the build identical

- The stable/unstable pairing is chosen per host in `modules/hosts/<host>.nix` (`instantiate`, `channel`) and `modules/hosts/<host>.nix`: beast uses `nixpkgs-unstable` + `home-manager` + `nixvim`; nas uses `nixpkgs` + `home-manager-stable` + `nixvim-stable`. The HM-version sniffs in `harness/_hm/` rely on this.
- Host aspect names must equal the `den.hosts` names (`beast`, `nas`), and those are also the `nixosConfigurations` names used by `update`, the nightly build and `lsp.nix`.
- Home Manager is still wired by hand (not Den's HM battery, no den users). User module `imports` order affects `home.packages` order and so the derivation; keep all user imports for a host in one list.
- Per-host data that Home Manager needs is a host attribute bridged to `home-manager.extraSpecialArgs` (e.g. `hardwareConfig` on beast).

## Adding a host

1. Add `hosts/_<name>-hardware.nix` (generated hardware config).
2. In `hosts/<name>.nix` declare `den.hosts.x86_64-linux.<name>` with `instantiate = mkInstantiate <nixpkgs channel>.lib.nixosSystem` (see an existing host), `channel`, `lan`, `tailscale` (and `mac`).
3. In the same file add `den.aspects.<name>`: `includes` for the roles/features, and a `nixos` module importing the matching Home Manager NixOS module and `./_<name>-hardware.nix`, holding the machine facts, plus the Home Manager user wiring.
4. `git add` the new files, then check `nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`.

## Adding an aspect

Create `<dir>/<name>.nix` with `den.aspects.<name>.nixos = { ... };` (a NixOS module; a function form gets `config`), then add `den.aspects.<name>` to a host aspect's `includes`. Supporting plain NixOS/Home Manager modules live under `_` names; the aspect imports them.

# modules/ (Den tree)

[Den](https://github.com/denful/den) (pinned in `flake.nix`) owns `nixosConfigurations`. Everything in this directory is a **flake-level module** (not a NixOS module), loaded by `import-tree ./modules` from `flake.nix`. import-tree skips every path containing `/_`: plain NixOS/Home Manager modules, package files, scripts and data live under `_` names and are imported explicitly by their aspect. Never leave a NixOS/HM module at a non-underscore path, and do not add a `default.nix` outside `_` paths (`check-imports` enforces the latter). Conventions and migration history: [`docs/Den-Native-Layout.md`](../docs/Den-Native-Layout.md).

| Path | Owns |
| --- | --- |
| `flake/` | Flake outputs other than hosts: `overlays.nix` (`overlays.default`, function in `_overlay.nix`), `packages.nix`, `checks.nix`, `formatter.nix` (`_pkgs.nix` builds the overlaid nixpkgs-unstable they use). |
| `hosts/<host>.nix` | The whole host: the `den.hosts` entry (`instantiate`, `channel`, `localAi`, `lan`, `tailscale`, `mac`, `hardwareConfig`, `home-manager.module`, users) and `den.aspects.<host>` (role/feature includes, `provides.to-users.homeManager`, machine facts in its `nixos` block). `_<host>-hardware.nix` is imported by it; `_instantiate.nix` is the shared `nixosSystem` wrapper (plain function). Host notes are `<host>.md`. |
| `defaults.nix`, `site.nix`, `secrets.nix`, `nix/`, `shell/`, `networking/`, `observability/` | Features that register themselves in `den.default.includes`, plus `den.default.nixos` settings that belong to no feature (`defaults.nix`). `site.nix` declares `codyos.site` and fills `codyos.site.hosts` from den host attributes. |
| `hardware/` | `hardware-baseline` (self-registered for every host) and `nvidia` (hosts with an NVIDIA GPU; `nvidiaPowerLimit` host attribute is the nvidia-smi cap in watts, nas only). |
| `users/` | `codyt.nix` (the codyt aspect: `user` class account + `homeManager`) and the editor/harness aspects it includes. Shell, git and CLI tools are features in `shell/`. |
| `desktop/` | `desktop.nix` role aspect plus one file per desktop feature (system and Home Manager halves together). Supporting HM modules/scripts under `_` names. |
| `editor/nixvim/` | `nixvim.nix` (channel-aware nixvim aspect), `desktop.nix` (`nixvim-desktop`), `_nixvim.nix`, `_keymaps.nix`, `_plugins/`. |
| `harness/` | AI/operator harness for the user (OpenCode, Claude Code, MCP, skills, plugins); HM tree in `_hm/`. |
| `ai/` | `llama-swap/`, `hermes-agent/`, `langfuse/` (dirs), `hindsight.nix`, `opencode.nix` (`opencode` server on nas, `opencode.remote` client on beast), `open-webui.nix`. |
| `documents/`, `media/` | `paperless.nix` (`paperless` on nas, `paperless.scanner` on beast), `paperless-gpt.nix`, `tika.nix`; the media stack (`media.nix` plus one file per service; imports `vpn-confinement`). |
| `web/`, `feeds/`, `containers/`, `observability/`, `backups/` | NAS ingress (`nginx`, `nginx.server`) and self-hosted web apps; Miniflux and its curator; `docker`/`docker.oci-backend`; monitoring and logging; Restic jobs and backup health. |

Machine facts (hardware import, mounts, networking, `stateVersion`s, host-specific settings) live in the host aspect's `nixos` block in `hosts/<host>.nix`.

## Rules that keep the build identical

- The stable/unstable pairing is a host fact set in `hosts/<host>.nix` (`instantiate`, `channel`, `home-manager.module`): beast uses `nixpkgs-unstable` + `home-manager` + `nixvim`; nas uses `nixpkgs` + `home-manager-stable` + `nixvim-stable`. The HM-version checks in `harness/_hm/` rely on this.
- Host aspect names must equal the `den.hosts` names (`beast`, `nas`); these are also the `nixosConfigurations` names used by `update`, the nightly build and `lsp.nix`.
- Home Manager comes from Den's home-manager integration: `modules/users/home-manager.nix` sets the shared options; each host sets `home-manager.module`; user aspects contribute through their `homeManager` class, and host aspects deliver role/host-specific user content through `provides.to-users.homeManager`.
- Per-host data that Home Manager needs is a host attribute (e.g. `hardwareConfig` on beast, `channel`, `localAi`) read from the `host` context.

## Adding a host

1. Add `hosts/_<name>-hardware.nix` (generated hardware config).
2. In `hosts/<name>.nix` declare `den.hosts.x86_64-linux.<name>` with `instantiate = mkInstantiate <nixpkgs input>.lib.nixosSystem` (copy an existing host), `channel`, `users.codyt = { }`, `home-manager.module`, `lan`, `tailscale` (and `mac`).
3. In the same file add `den.aspects.<name>`: `includes` for the roles/features, `provides.to-users.homeManager` (at least `home.stateVersion`), and a `nixos` block that imports `./_<name>-hardware.nix` and holds the machine facts.
4. `git add` the new files, then check `nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`.

## Adding an aspect

Create `<dir>/<name>.nix` with `den.aspects.<name> = { nixos = …; homeManager = …; includes = [ … ]; };` (use only the classes you need; a function form gets `config`, `pkgs`, …), then add `den.aspects.<name>` to a role or host aspect's `includes`. Supporting plain NixOS/Home Manager modules live under `_` names and are imported by the aspect.

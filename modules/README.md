# modules/ (Den tree)

[Den](https://github.com/denful/den) (pinned in `flake.nix`) owns `nixosConfigurations`. Everything in this directory is a **flake-level module** (not a NixOS module), loaded by `import-tree ./modules` from `flake.nix`. import-tree skips every path containing `/_`: plain NixOS/Home Manager modules, package files, scripts and data live under `_` names and are imported explicitly by their aspect. Never leave a NixOS/HM module at a non-underscore path, and do not add a `default.nix` outside `_` paths (`check-imports` enforces the latter). Conventions and migration history: [`docs/Den-Native-Layout.md`](../docs/Den-Native-Layout.md).

The tree is organized by **feature**, not by machine role: there is no `base`, `server` or `desktop` role. A host (`hosts/<host>.nix`) lists the features it wants; features that every host needs register themselves.

## Layout

| Path | Owns |
| --- | --- |
| `flake/` | Flake outputs other than hosts: `overlays.nix` (`overlays.default`, function in `_overlay.nix`), `packages.nix`, `checks.nix`, `formatter.nix` (`_pkgs.nix` builds the overlaid nixpkgs-unstable they use). |
| `hosts/<host>.nix` | The whole host: the `den.hosts` entry (`instantiate`, `channel`, `localAi`, `lan`, `tailscale`, `mac`, `hardwareConfig`, `home-manager.module`, users) and `den.aspects.<host>` (the feature includes, `provides.to-users.homeManager`, machine facts in its `nixos` block). `_<host>-hardware.nix` is imported by it; `_instantiate.nix` is the shared `nixosSystem` wrapper (plain function). Host notes are `<host>.md`. |
| `defaults.nix`, `site.nix`, `secrets.nix`, `nix/`, `shell/`, `networking/`, `observability/logging.nix`, `web/nginx.nix`, `hardware/baseline.nix`, `users/home-manager.nix`, `editor/nixvim.nix`, `harness/harness.nix` | Features on every host; each registers itself in `den.default.includes` (list them with the command in the next section). `defaults.nix` holds only the `den.default.nixos` settings that belong to no feature. `site.nix` declares `codyos.site` and fills `codyos.site.hosts` from den host attributes. |
| `hardware/` | `baseline` (every host), `nvidia` (hosts with an NVIDIA GPU; `nvidiaPowerLimit` host attribute is the nvidia-smi cap in watts, nas only) and `openrazer` (opt-in). |
| `users/` | `codyt.nix` (the codyt aspect: `user` class account + `homeManager`) and `home-manager.nix` (shared Home Manager options). |
| `shell/`, `editor/`, `harness/` | The user's shell and git, NixVim (`nixvim`, `nixvim.desktop`; `_nixvim.nix`, `_keymaps.nix`, `_plugins/`), and the AI/operator harness (HM tree in `_hm/`). |
| `graphical/` | `den.aspects.graphical`: the Wayland desktop session on a workstation, one aspect over several files (`session.nix`, `hyprland.nix` + Waybar, `launcher.nix`, `notifications.nix`, `xdg.nix`, `theming.nix`). |
| `apps/` | `den.aspects.apps`: the user's desktop applications, one aspect over `apps.nix`, `terminal.nix` and `kdeconnect.nix` (`_obsidian/`). |
| `development/` | `project`, the Nix template CLI selected on Beast. |
| `audio.nix`, `printing.nix`, `gaming.nix` | Standalone single-file features that a workstation host includes. |
| `file-sharing/`, `containers/` | `syncthing` (and `syncthing.nginx`), `nfs.server` / `nfs.client`, and `samba.server`; `docker` (and `docker.oci-backend`). Paperless owns its own SMB scanner handoff. |
| `networking/`, `nix/` | Networking (`dns`, `wake-on-lan.target`); the Nix daemon and `binary-cache` (`.server` / `.client`) and the nightly build. |
| `ai/` | `llama-swap/`, `hermes-agent/` (including Beast's `hermes-voice-client`), `langfuse/` (dirs), `hindsight.nix`, `opencode.nix` (`opencode` server on nas, `opencode.remote` client on beast), `open-webui.nix`, `speech-to-text.nix` (the client of the NAS llama-swap speech endpoints). |
| `documents/`, `media/` | `paperless.nix` (`paperless` on nas, `paperless.scanner` on beast), `paperless-gpt.nix`, `tika.nix`; the media stack (`media.nix` plus one file per service; imports `vpn-confinement`). |
| `web/`, `feeds/`, `observability/`, `backups/` | NAS ingress (`nginx`, `nginx.server`) and self-hosted web apps; Miniflux and its curator; monitoring, uptime and logging (`logging`, `logging.desktop`); Restic jobs and backup health. |

Machine facts (hardware import, mounts, networking, `stateVersion`s, host-specific settings) live in the host aspect's `nixos` block in `hosts/<host>.nix`.

## Which features are on every host

```bash
nix eval --impure --json --expr 'let f = builtins.getFlake (toString ./.); inputs = f.inputs // { self = f; }; ev = inputs.nixpkgs.lib.evalModules { modules = [ inputs.den.flakeModule (inputs.import-tree ./modules) ]; specialArgs = { inherit inputs; }; }; in map (a: a.name or "?") ev.config.den.default.includes'
```

Run it from the repository root (after `git add`ing new files). The last few names (`wsl-to-host`, `unfree-predicate`, `user-to-host`, `os-to-host`, `insecure-predicate`) are Den's own policies, not repo features. Grep fallback: `grep -rn 'den.default.includes' modules`.

## Rules that keep the build identical

- The stable/unstable pairing is a host fact set in `hosts/<host>.nix` (`instantiate`, `channel`, `home-manager.module`): beast uses `nixpkgs-unstable` + `home-manager` + `nixvim`; nas uses `nixpkgs` + `home-manager-stable` + `nixvim-stable`. The HM-version checks in `harness/_hm/` rely on this.
- Host aspect names must equal the `den.hosts` names (`beast`, `nas`); these are also the `nixosConfigurations` names used by `update`, the nightly build and `lsp.nix`.
- Home Manager comes from Den's home-manager integration: `modules/users/home-manager.nix` sets the shared options; each host sets `home-manager.module`; features contribute through their `homeManager` class (or `provides.to-users.homeManager`), and host aspects deliver host-specific user content through `provides.to-users.homeManager`.
- Per-host data that Home Manager needs is a host attribute (e.g. `hardwareConfig` on beast, `channel`, `localAi`) read from the `host` context.
- Include order matters for list-valued options: Den concatenates included modules in reverse include order (see the comment in `hosts/nas.nix`).

## Adding a host

1. Add `hosts/_<name>-hardware.nix` (generated hardware config).
2. In `hosts/<name>.nix` declare `den.hosts.x86_64-linux.<name>` with `instantiate = mkInstantiate <nixpkgs input>.lib.nixosSystem` (copy an existing host), `channel`, `users.codyt = { }`, `home-manager.module`, `lan`, `tailscale` (and `mac`).
3. In the same file add `den.aspects.<name>`: `includes` listing the features the host wants, `provides.to-users.homeManager` (at least `home.stateVersion`), and a `nixos` block that imports `./_<name>-hardware.nix` and holds the machine facts.
4. `git add` the new files, then check `nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`.

## Adding a feature

Create `<area>/<feature>.nix` with `den.aspects.<feature> = { nixos = …; homeManager = …; };` (use only the classes you need; a function form gets `config`, `pkgs`, …).

- Every host needs it: add `den.default.includes = [ den.aspects.<feature> ];` to the same file (take `den` as a module argument: `{ den, ... }:`).
- Only some hosts need it: add `den.aspects.<feature>` to those hosts' `includes`.
- It has a server and a client side (or similar): one aspect per side, `den.aspects.<feature>.server` / `.client`, each included by the host that needs it. Including the parent does not include its children.
- It outgrows one file: add more files that contribute to the **same** aspect (`den.aspects.<feature>` is merged across files, as in `graphical/` and `apps/`). Within one file, define each aspect class path once.
- Supporting plain NixOS/Home Manager modules, scripts and data live under `_` names and are imported by the aspect.

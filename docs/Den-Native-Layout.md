# Den-native layout

`modules/` *is* the Den tree. Every non-underscore `.nix` file under `modules/` is a flake-level
module, loaded by `import-tree`, that contributes to `den.*` (usually one `den.aspects.<feature>`
with its `nixos` and `homeManager` halves) or to `flake.*` (flake outputs). Hosts are short lists
of features plus their facts. There is no separate `den/`, `hosts/` or `users/` tree, and no
machine-role aspects (`base`, `server`, `desktop`): the tree is organized by **feature**.

`flake.nix` is inputs plus one expression: `evalModules` over `inputs.den.flakeModule` and
`inputs.import-tree ./modules`, taking `.config.flake` as the flake outputs (minus Den's own
`denful` export). Modules receive `inputs` (including `inputs.self`) as a module argument.

## Current layout

```
flake.nix                    # inputs + evalModules(...).config.flake
packages/                    # package trees (package.nix each); exposed by the overlay
modules/
  flake/                     # overlays.nix, packages.nix, checks.nix, formatter.nix as flake.*
                             #   definitions; _overlay.nix (overlay function), _pkgs.nix
  hosts/
    beast.nix, nas.nix       # den.hosts.x86_64-linux.<h> (channel pairing, facts) and
                             #   den.aspects.<h> (feature includes, provides.to-users, machine facts)
    _instantiate.nix         # shared nixosSystem wrapper (plain Nix function)
    _beast-hardware.nix, _nas-hardware.nix
    beast.md, nas.md         # host notes
  # on every host (each registers itself in den.default.includes):
  defaults.nix site.nix secrets.nix            # no-feature settings (small); site facts; sops
  nix/ shell/ networking/ observability/       # nix + binary-cache, shell + git, networking, logging
  users/ hardware/ editor/ harness/            # account + home-manager; baseline; nixvim; AI harness
  web/nginx.nix                                # nginx (the NAS ingress side is nginx.server)
  # opt-in features, listed by the hosts that want them:
  graphical/                 # den.aspects.graphical: Hyprland session, launcher, theming, ...
  apps/                      # den.aspects.apps: desktop applications, terminal, KDE Connect
  audio.nix printing.nix gaming.nix            # standalone single-file features
  hardware/nvidia.nix openrazer.nix            # hardware-specific opt-ins
  sync/ file-sharing/ containers/              # syncthing; nfs, samba; docker
  ai/ documents/ media/                        # llama-swap, hermes-agent, langfuse, hindsight,
                                               #   opencode(.remote), open-webui, speech-to-text;
                                               #   paperless(.scanner), paperless-gpt, tika; media stack
  web/ feeds/ backups/                         # NAS web apps; miniflux; restic jobs
  # (observability/ also holds monitoring.nix, uptime-kuma.nix and logging.desktop)
```

Each directory has a README or AGENTS.md where there is something to know; the top-level
[`modules/README.md`](../modules/README.md) has the per-path table.

## Conventions

- **Feature first.** A directory or file is named for what it does (`graphical`, `audio`,
  `paperless`, `backups`), never for the machine that uses it. There are no role folders and no
  role aspects. A host lists the features it wants in `den.aspects.<host>.includes`
  (`modules/hosts/<host>.nix`); that list is the whole composition.
- **Universal features register themselves.** A feature that every host needs puts
  `den.default.includes = [ den.aspects.<feature> ];` in its own file (this works for both the
  `nixos` and `homeManager` halves). List what is on every host:

  ```bash
  nix eval --impure --json --expr 'let f = builtins.getFlake (toString ./.); inputs = f.inputs // { self = f; }; ev = inputs.nixpkgs.lib.evalModules { modules = [ inputs.den.flakeModule (inputs.import-tree ./modules) ]; specialArgs = { inherit inputs; }; }; in map (a: a.name or "?") ev.config.den.default.includes'
  ```

  Run from the repository root; the last few names (`wsl-to-host`, `unfree-predicate`,
  `user-to-host`, `os-to-host`, `insecure-predicate`) are Den's own policies. Fallback:
  `grep -rn 'den.default.includes' modules`. Hosts do not repeat these.
- **Cross-host features live in one place, one aspect per side.** A feature with a server and a
  client (or similar) is one file with nested aspects `den.aspects.<feature>.<side>`:
  `nfs.server` / `nfs.client`, `opencode` / `opencode.remote`, `paperless` / `paperless.scanner`,
  `nginx.server`, `logging.desktop`, `nixvim.desktop`. Each host includes the side it needs.
  Including a parent does not include its children, and `<aspect>._` is not used.
- **Aspect = unit of inclusion; file = unit of reading.** Make a separate aspect only when some
  host includes it independently. Size files for readers (roughly 30–250 lines): merge tiny
  files of one feature, and do not keep pointer files. One aspect may span a directory:
  `den.aspects.<x>` is merged across files, so `graphical/` (session, hyprland, launcher,
  notifications, xdg, theming) and `apps/` (apps, terminal, kdeconnect) are one aspect each.
  Within a single file, define each aspect class path (`nixos`, `provides.to-users.homeManager`)
  only once. Den places the pieces of a multi-file aspect ahead of include-ordered features, so
  list-valued options such as `environment.systemPackages` can come out in a different order than
  a one-file aspect would give; the sets are the same.
- **`modules/defaults.nix` is only for settings with no feature**, and stays small. Anything
  with a name of its own gets a feature file that registers itself.
- **Inclusion replaces enable flags.** A host including `den.aspects.<x>` (or the aspect being in
  `den.default.includes`) turns the feature on; there are no `codyos.<x>.enable` gates.
- **Per-host facts live on the host** (`den.hosts.x86_64-linux.<h>.<attr>`: `channel`, `localAi`,
  `lan`, `tailscale`, `mac`, `hardwareConfig`, `nvidiaPowerLimit`, `home-manager.module`),
  declared in `modules/hosts/<h>.nix` and read by aspects through the `host` context argument,
  not by comparing `networking.hostName` strings.
- **`codyos.site` is the consumer interface** for shared site facts: declared in
  `modules/site.nix`, populated from host attributes, read as `config.codyos.site`
  (NixOS) or `osConfig.codyos.site` (Home Manager).
- **Underscore = not a Den module.** import-tree skips any path containing `/_`. Every `.nix`
  that is not a flake-level module (package.nix, data files, script builders, large single-class
  subtrees such as the hermes plugin/skill tree, nixvim plugins, Hyprland/Waybar settings) lives
  under a `_` name and is imported explicitly by its aspect.
- **No `default.nix` outside `_` paths.** `check-imports` (see `packages/check-imports/README.md`)
  enforces this and, inside `_` subtrees that still use `default.nix`, that sibling files are
  referenced from it.
- **Stable/unstable pairing is a host fact**: beast = nixpkgs-unstable + home-manager + nixvim;
  nas = nixpkgs + home-manager-stable + nixvim-stable.
- **Host names `beast` and `nas` are load-bearing** (`update`, `nightly-build.nix`, `lsp.nix`).
- **Include order matters for list-valued options**: Den concatenates included modules in
  reverse include order (see the comment at the top of nas's includes).
- **Flake outputs** are `flake.<output>` definitions in `modules/flake/`. Den's `flake` option
  is a freeform submodule (`nix/flakeOutputs.nix`), so no flake-parts is needed.

## How to add things

- **Host**: see [`modules/README.md`](../modules/README.md#adding-a-host).
- **Feature (aspect)**: create `modules/<area>/<feature>.nix` with
  `den.aspects.<feature> = { nixos = …; homeManager = …; };`. Then pick one:
  every host needs it → add `den.default.includes = [ den.aspects.<feature> ];` to the same file
  (`{ den, ... }:` as the module argument); otherwise add `den.aspects.<feature>` to the
  `includes` of the hosts that want it. If it grows, add more files in the same directory that
  contribute to the same aspect, or move supporting modules under `_` names.
- **Cross-host feature**: one file, one aspect per side
  (`den.aspects.<feature>.server` / `.client`); each host includes its side.
- **NAS service**: a new `modules/web/<service>.nix` (or the feature directory it belongs to)
  defining `den.aspects.<service>.nixos` (secrets, nginx vhost, firewall and backups next to it),
  included from `den.aspects.nas` in `modules/hosts/nas.nix`.
- **Flake output**: a new file in `modules/flake/` defining `flake.<output>`.
- New files must be `git add`-ed before Nix sees them.

## Migration history

The tree was moved to this layout on branch `use-den` in slices 0–8: relocation of `den/`,
`hosts/`, `users/` and the old `modules/*` trees; hosts and site facts; users and Home Manager;
cross-class services; base and hardware; desktop; user/editor/harness; server (one aspect per
service); finish (flake outputs as modules, docs). Each slice kept both hosts' system `drvPath`
identical to the pre-migration baseline, except where a commit message explains an
ordering-only difference.

A second pass, the **feature reorganization** (the `den-features` slices 1–8), then dissolved the
machine-role trees `base/`, `server/`, `services/` and `desktop/`: their contents moved into
feature directories (`nix/`, `shell/`, `networking/`, `observability/`, `web/`, `feeds/`,
`containers/`, `backups/`, `ai/`, `documents/`, `media/`, `sync/`, `file-sharing/`, `graphical/`,
`apps/`, …), the `base`, `server` and `desktop` role aspects were deleted, universal features
self-register through `den.default.includes`, cross-host features became nested
`<feature>.<side>` aspects, and hosts now list features directly. Both hosts' system `drvPath`
stayed identical per slice except where a commit message explains a path-string or ordering-only
difference (slice 7: beast package order, because Den places the pieces of the multi-file
`graphical` and `apps` aspects ahead of include-ordered features).

Old paths named in older notes map as follows:

| Old | New |
|---|---|
| `den/hosts*.nix`, `hosts/<h>/default.nix` | `modules/hosts/<h>.nix` |
| `hosts/<h>/hardware-configuration.nix`, `hosts/nas/models.nix` | `modules/hosts/_<h>-hardware.nix`, `modules/ai/llama-swap/_nas-models.nix` |
| `den/aspects/*` | dissolved into the feature dirs |
| `modules/system/*` | `defaults.nix`, `nix/`, `shell/`, `networking/`, `observability/`, `secrets.nix`, `site.nix` |
| `modules/nas/*`, `modules/server/*`, `modules/services/*` | feature directories: `web/`, `feeds/`, `containers/`, `observability/`, `backups/`, `ai/`, `documents/`, `media/` |
| `users/cody/desktop*`, `modules/desktop/*` | `modules/graphical/`, `modules/apps/`, `modules/audio.nix`, `modules/printing.nix`, `modules/gaming.nix` |
| `modules/desktop/desktop.nix` (`desktop` role), `den.aspects.desktop` | deleted; beast includes `graphical`, `apps`, `audio`, `printing`, `gaming`, … directly |
| `modules/desktop/{hyprland,rofi,wifi,waybar,notifications,xdg,theming,fonts,wayland-session,nvidia-session}.nix` | `modules/graphical/{hyprland,launcher,notifications,xdg,theming,session}.nix` (aspect `graphical`) |
| `modules/desktop/{apps,programs,browser,obsidian,terminal,scripts,kdeconnect}.nix` | `modules/apps/{apps,terminal,kdeconnect}.nix` (aspect `apps`) |
| `modules/desktop/openrazer.nix` | `modules/hardware/openrazer.nix` |
| `modules/desktop/desktop-logging.nix` | `modules/observability/logging.nix` (`logging.desktop`) |
| `modules/desktop/{speech-to-text.nix,_speech-to-text.nix}` | `modules/ai/` |
| `modules/editor/nixvim/*` (`nixvim-desktop`) | `modules/editor/nixvim.nix` (`nixvim`, `nixvim.desktop`), `_nixvim.nix`, `_keymaps.nix`, `_plugins/` |
| `modules/base/*`, `den.aspects.base` | `defaults.nix`, `nix/`, `shell/`, `networking/`, `hardware/baseline.nix`, `secrets.nix`, `users/` (each self-registering) |
| `modules/server/server.nix`, `den.aspects.server` | `web/nginx.nix` (`nginx.server`), `containers/docker.nix` (`docker.oci-backend`); nas includes the features directly |
| `modules/services/*` | `ai/`, `containers/`, `sync/`, `file-sharing/`, `documents/` |
| `overlays/default.nix`, flake.nix outputs | `modules/flake/*` |

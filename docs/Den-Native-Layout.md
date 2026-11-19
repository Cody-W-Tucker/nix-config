# Den-native layout

`modules/` *is* the Den tree. Every non-underscore `.nix` file under `modules/` is a flake-level
module, loaded by `import-tree`, that contributes to `den.*` (usually one `den.aspects.<feature>`
with its `nixos` and `homeManager` halves) or to `flake.*` (flake outputs). Hosts are short lists
of includes plus their facts. There is no separate `den/`, `hosts/` or `users/` tree.

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
                             #   den.aspects.<h> (includes, provides.to-users, machine facts)
    _instantiate.nix         # shared nixosSystem wrapper (plain Nix function)
    _beast-hardware.nix, _nas-hardware.nix
    beast.md, nas.md         # host notes
  # shared features, each registering itself in den.default.includes:
  defaults.nix site.nix secrets.nix  # no-feature settings; site facts; sops imports
  nix/ shell/ networking/ observability/  # nix, shell, networking, logging aspects
  # (home-manager is in users/home-manager.nix)
  hardware/                  # baseline, nvidia
  users/                     # codyt.nix (account + HM profile) and shared user aspects
  desktop/                   # `desktop` role + one file per feature, both halves together;
                             #   _hyprland/, _waybar/, _obsidian/, _scripts/, _speech-to-text.nix
  editor/nixvim/             # nixvim aspects + _plugins/ (plain HM modules)
  harness/                   # AI/operator harness; _hm/ holds the HM module tree
  services/                  # hermes-agent/, llama-swap/, opencode.nix, hindsight.nix,
                             #   docker.nix, nginx.nix, syncthing.nix, paperless-scanning.nix,
                             #   automations/
  server/                    # `server` role + one aspect per NAS service
                             #   (media/, binary-cache/, langfuse/, backups, monitoring, …)
```

## Conventions

- **File = feature.** One file owns a concern across classes (`nixos`, `homeManager`);
  NixOS/HM pairs that serve one feature are merged into one file.
- **Inclusion replaces enable flags.** A host (or role) including `den.aspects.<x>` turns the
  feature on; there are no `codyos.<x>.enable` gates.
- **Per-host facts live on the host** (`den.hosts.x86_64-linux.<h>.<attr>`: `channel`, `localAi`,
  `lan`, `tailscale`, `mac`, `hardwareConfig`, `nvidiaPowerLimit`, `home-manager.module`),
  declared in `modules/hosts/<h>.nix` and read by aspects through the `host` context argument,
  not by comparing `networking.hostName` strings.
- **`codyos.site` is the consumer interface** for shared site facts: declared in
  `modules/site.nix`, populated from host attributes, read as `config.codyos.site`
  (NixOS) or `osConfig.codyos.site` (Home Manager).
- **Underscore = not a Den module.** import-tree skips any path containing `/_`. Every `.nix`
  that is not a flake-level module (package.nix, data files, script builders, large single-class
  subtrees such as the hermes plugin/skill tree or nixvim plugins) lives under a `_` name and is
  imported explicitly by its aspect.
- **No `default.nix` outside `_` paths.** `check-imports` (see `packages/check-imports/README.md`)
  enforces this and, inside `_` subtrees that still use `default.nix`, that sibling files are
  referenced from it.
- **Stable/unstable pairing is a host fact**: beast = nixpkgs-unstable + home-manager + nixvim;
  nas = nixpkgs + home-manager-stable + nixvim-stable.
- **Host names `beast` and `nas` are load-bearing** (`update`, `nightly-build.nix`, `lsp.nix`).
- **Flake outputs** are `flake.<output>` definitions in `modules/flake/`. Den's `flake` option
  is a freeform submodule (`nix/flakeOutputs.nix`), so no flake-parts is needed.

## How to add things

- **Host**: see [`modules/README.md`](../modules/README.md#adding-a-host).
- **Aspect**: create `modules/<area>/<name>.nix` with `den.aspects.<name> = { nixos = …; homeManager = …; };`
  and add `den.aspects.<name>` to a role or host aspect's `includes`.
- **NAS service**: a new `modules/server/<service>.nix` defining `den.aspects.<service>.nixos`
  (secrets, nginx vhost, firewall and backups next to it), included from `modules/server/server.nix`.
- **Flake output**: a new file in `modules/flake/` defining `flake.<output>`.
- New files must be `git add`-ed before Nix sees them.

## Migration history

The tree was moved to this layout on branch `use-den` in slices 0–8: relocation of `den/`,
`hosts/`, `users/` and the old `modules/*` trees; hosts and site facts; users and Home Manager;
cross-class services; base and hardware; desktop; user/editor/harness; server (one aspect per
service); finish (flake outputs as modules, docs). Each slice kept both hosts' system `drvPath`
identical to the pre-migration baseline, except where a commit message explains an
ordering-only difference. Old paths named in older notes map as follows:

| Old | New |
|---|---|
| `den/hosts*.nix`, `hosts/<h>/default.nix` | `modules/hosts/<h>.nix` |
| `hosts/<h>/hardware-configuration.nix`, `hosts/nas/models.nix` | `modules/hosts/_<h>-hardware.nix`, `modules/services/llama-swap/_nas-models.nix` |
| `den/aspects/*` | dissolved into the feature dirs, `desktop/`, `server/`, `services/` |
| `modules/system/*` | `defaults.nix`, `nix/`, `shell/`, `networking/`, `observability/`, `secrets.nix`, `site.nix` |
| `modules/nas/*` | `modules/server/*` |
| `users/cody/desktop*` | `modules/desktop/*` |
| `users/cody/{core,server}.nix` | `modules/users/*` and host `provides.to-users` |
| `users/cody/editor/*`, `users/cody/harness/*` | `modules/editor/*`, `modules/harness/*` |
| `overlays/default.nix`, flake.nix outputs | `modules/flake/*` |

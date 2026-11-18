# Den-native layout (target)

Goal: `modules/` *is* the Den tree. Every non-underscore `.nix` file under `modules/` is a
flake-level module, loaded by `import-tree`, that contributes to `den.*` (usually one
`den.aspects.<feature>` with its `nixos` and `homeManager` halves). Hosts are short lists of
includes plus their facts. There is no separate `den/`, `hosts/` or `users/` tree.

## Target tree

```
flake.nix                    # inputs + evalModules over (import-tree ./modules)
packages/                    # unchanged: package trees exposed by the overlay
modules/
  flake/                     # flake outputs as modules: overlays, packages, checks, formatter
  site.nix                   # shared site facts (domain, LAN, user) — flake-level data
  hosts/
    beast.nix                # den.hosts.x86_64-linux.beast: channel pairing (instantiate,
                             #   HM module), facts (lan, tailscale, mac, hardwareConfig, …),
                             #   users, and den.aspects.beast { includes; nixos = machine facts }
    nas.nix
    _instantiate.nix         # shared nixosSystem wrapper (plain Nix function)
    _beast-hardware.nix      # hardware-configuration.nix, imported by the host aspect
    _nas-hardware.nix
    _nas-models.nix
  users/
    codyt.nix                # user aspect: account + HM core (shell, git, cli), includes
                             #   editor and harness
  base/                      # one aspect per concern (nix, locale, networking, logging,
                             #   shell, sops, packages, scripts, overlays, home-manager …);
                             #   `base` includes them all
  hardware/                  # baseline, nvidia
  desktop/                   # one file per feature with BOTH halves, e.g. hyprland.nix =
                             #   system Hyprland + the user's Hyprland settings;
                             #   `desktop` role includes them; gaming, openrazer, printing …
  editor/nixvim/             # nixvim.nix aspect (picks nixvim vs nixvim-stable by channel)
                             #   + _plugins/ (plain HM modules)
  harness/                   # claude-code, opencode client, mcp, skills, plugins
  services/                  # hermes-agent/, opencode.nix, hindsight.nix, llama-swap/,
                             #   syncthing.nix, nginx.nix, docker.nix, paperless-scanning.nix …
  server/                    # former modules/nas/*: one aspect per service;
                             #   `server` role includes them
```

## Conventions

- **File = feature.** One file owns a concern across classes (`nixos`, `homeManager`).
  NixOS/HM pairs that serve one feature are merged into one file.
- **Inclusion replaces enable flags.** `codyos.<x>.enable` options that only gate a feature are
  deleted; a host (or role) including `den.aspects.<x>` turns it on. Options that carry values
  may become host attributes read by the aspect, or stay as options when that is simpler.
- **Per-host facts live on the host** (`den.hosts.x86_64-linux.<h>.<attr>`), declared in
  `modules/hosts/<h>.nix`, and are read by aspects through the `host` context argument — not by
  comparing `networking.hostName` strings. Planned host attributes: `channel`
  (`"unstable"`/`"stable"`), `lan`, `tailscale`, `mac`, `hardwareConfig` (beast), `localAi`
  (true where llama-swap/hindsight/qmd run locally — replaces `hostName == "nas"`).
- **`codyos.site` stays the consumer interface** for now: it is populated from host attributes
  and `modules/site.nix`, so the ~dozens of `config.codyos.site` / `osConfig.codyos.site`
  readers keep working unchanged.
- **Underscore = not a Den module.** import-tree skips any path containing `/_`. Every `.nix`
  that is not a flake-level module (package.nix, data files, script builders, large single-class
  subtrees like the hermes plugin/skill tree or nixvim plugins) lives under a `_` name and is
  imported explicitly by its aspect.
- **No `default.nix` outside `_` paths.** `check-imports` (sibling files must be referenced from
  `default.nix`) keeps applying inside `_` subtrees that still use `default.nix`.
- **Stable/unstable pairing is a host fact**: beast = nixpkgs-unstable + home-manager + nixvim;
  nas = nixpkgs + home-manager-stable + nixvim-stable.
- **Host names `beast` and `nas` are load-bearing** (`update`, `nightly-build.nix`, `lsp.nix`).

## Old → new map

| Old | New |
|---|---|
| `den/hosts.nix`, `den/hosts/<h>.nix`, `hosts/<h>/default.nix` | `modules/hosts/<h>.nix` (+ `_instantiate.nix`) |
| `hosts/<h>/hardware-configuration.nix`, `hosts/nas/models.nix` | `modules/hosts/_<h>-hardware.nix`, `_nas-models.nix` |
| `den/aspects/{base,desktop,nas-role,features,hermes-agent}.nix` | dissolved into `base/`, `desktop/`, `server/`, `services/` |
| `modules/system/*` | `modules/base/*` |
| `modules/hardware/*` | `modules/hardware/*` |
| `modules/desktop/*` + `users/cody/desktop/*` | `modules/desktop/*` (merged pairs) |
| `modules/services/*` | `modules/services/*` |
| `modules/nas/*` | `modules/server/*` |
| `users/home.nix` | Den HM integration settings in `modules/base/home-manager.nix` |
| `users/cody/{core,server,desktop}.nix` | `modules/users/codyt.nix` + role/host includes |
| `users/cody/editor/*`, `users/cody/harness/*` | `modules/editor/*`, `modules/harness/*` |
| `overlays/default.nix`, flake.nix outputs | `modules/flake/*` (last slice, optional) |

## Migration slices

Every slice starts from a green, committed tree. Its start commit is recorded in
`/tmp/den-migration/slices.log`. Within a slice:

1. **Move commit** — `git mv` files to their target paths (non-modules under `_` names) and fix
   only the import paths/wiring needed to evaluate. Expected gate result: IDENTICAL.
2. **Rewrite commit(s)** — convert contents into native aspects. Expected gate result:
   IDENTICAL or CHANGED-with-every-difference-explained.

Gate (`/tmp/den-migration/gate2.sh`): compares each host's system drvPath to the pre-migration
baseline; if changed, builds it, writes `nix store diff-closures` and `nix-diff` output. A CHANGED
result passes only if the closure diff is empty (or each line is explained) and every nix-diff
hunk is shown to be ordering-only or otherwise behavior-neutral, written up in the commit
message. Also required: `nix flake check` passes.

If a slice cannot be made to pass: `git reset --hard <slice start>` and report.

| # | Slice | Scope |
|---|---|---|
| 0 | Relocate | `den/*` → `modules/{hosts,…}`; old `modules/*` → `modules/_legacy/*`; `users/` → `modules/_legacy/users/`; `hosts/` → `modules/_legacy/hosts/`; `flake.nix` loads `import-tree ./modules`. Pure move, IDENTICAL. |
| 1 | Hosts & site | `modules/hosts/<h>.nix` absorbs instantiate + host facts + machine config; hardware/models become `_` files; host attributes feed `codyos.site`. |
| 2 | Users & Home Manager | Den users + Den HM integration replace hand wiring (`users/home.nix`, `extraSpecialArgs`, per-host user imports); `hardwareConfig` and `localAi` read from host context; `hostName == "nas"` branches replaced. |
| 3 | Cross-class services | hermes-agent (HM + backups in one aspect), opencode (service + client), hindsight, llama-swap, paperless-scanning, docker, nginx, syncthing. |
| 4 | Base & hardware | `modules/base/*`, `modules/hardware/*`; nvidia as aspect (power limit as host attribute or option). |
| 5 | Desktop | merge `modules/desktop` + `users/cody/desktop` pairs; gaming, openrazer, printing, audio, hyprland … |
| 6 | User, editor, harness | `users/codyt.nix`, `editor/nixvim`, `harness/`. |
| 7 | Server | `modules/nas/*` → `modules/server/*`, one aspect per service, `server` role. |
| 8 | Finish | flake outputs into `modules/flake/` (if clean), delete `_legacy`, rewrite AGENTS.md files, docs, `den/README.md` → this doc. |

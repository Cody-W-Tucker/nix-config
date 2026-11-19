# Web apps and NAS ingress

Owns `nginx.nix` (`mkNginxVhost` on every host; `den.aspects.nginx.server`, the NAS ingress) and one `den.aspects.<service>` per self-hosted single-service web app, each a NixOS module in the aspect's `nixos` block. `README.md` documents the ingress and the domain map. The same rules apply to the other NAS service directories (`feeds/`, `observability/`, `backups/`, `ai/`, `documents/`, `media/`).

Does not own one-host facts (those are in `modules/hosts/nas.md`/`nas.nix`) or Home Manager/user preferences (`modules/users/`, `modules/harness/`).

## Rules

- Add a service as `modules/web/<name>.nix` with `den.aspects.<name>.nixos = ...` and include it from `den.aspects.nas` in `modules/hosts/nas.nix`. A pure enable gate is the include, not an option. Features organize by what they are, not by machine role: there is no `server` role aspect.
- Keep `nas.backups.*` (declared in `modules/backups/_backup-options.nix`) as the way services register Restic data and SQLite exports. Include order in `den.aspects.nas.includes` fixes the order of those lists (den concatenates included modules in reverse include order); do not reorder the list casually.
- `den.aspects.wake-on-lan.waker` (modules/networking/wake-on-lan.nix) is declared but included nowhere on purpose.
- Declare secrets next to the consuming service, with quoted names for dashed keys.
- Never hardcode the domain, username, home path, email, LAN subnet or host addresses. Read `config.codyos.site`; name vhosts `"<name>.${domain}"` with `inherit (config.codyos.site) domain;` and use `mkNginxVhost`.
- Keep custom options under `codyos.*`/`nas.*`, not upstream namespaces, unless deliberately extending an upstream module.
- Upstream NixOS modules are imported by the one aspect that uses their options (`vpn-confinement` by `media`, `workflow` by `hermes-agent`), never at several sites.

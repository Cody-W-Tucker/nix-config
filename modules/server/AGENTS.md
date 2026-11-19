# Server (nas) services

Owns the `server` role aspect (`server.nix`) and one `den.aspects.<service>` per self-hosted nas service, each a NixOS module in the aspect's `nixos` block. Multi-file services are a directory with an aspect file and `_` supporting files (`media/`, `langfuse/`). `README.md` documents the services.

Does not own one-host facts (those are in `modules/hosts/nas.md`/`nas.nix`) or Home Manager/user preferences (`modules/users/`, `modules/harness/`).

## Rules

- Add a service as `modules/server/<name>.nix` with `den.aspects.<name>.nixos = ...` and include it from `server.nix`. A pure enable gate is the include, not an option.
- Keep `nas.backups.*` (declared in `_backup-options.nix`) as the way services register Restic data and SQLite exports. Include order in `server.nix` fixes the order of those lists (den concatenates included modules in reverse include order).
- `den.aspects.wake-on-lan.waker` (modules/networking/wake-on-lan.nix) is declared but included nowhere on purpose.
- Declare secrets next to the consuming service, with quoted names for dashed keys.
- Never hardcode the domain, username, home path, email, LAN subnet or host addresses. Read `config.codyos.site`; name vhosts `"<name>.${domain}"` with `inherit (config.codyos.site) domain;` and use `mkNginxVhost`.
- Keep custom options under `codyos.*`/`nas.*`, not upstream namespaces, unless deliberately extending an upstream module.

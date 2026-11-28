# Web apps and NAS ingress

Owns `nginx.nix` (`mkNginxVhost` on every host; `den.aspects.nginx.server`, the NAS ingress) and one `den.aspects.<service>` per self-hosted single-service web app. See [Web apps](../../docs/src/web-apps.md) for user-facing addresses. The same rules apply to the other NAS service directories (`feeds/`, `observability/`, `backups/`, `ai/`, `documents/`, `media/`).

Does not own machine facts (`modules/hosts/nas.nix`) or Home Manager/user preferences (`modules/users/`, `modules/ai/harness/`).

## Rules

- Add a service as `modules/web/<name>.nix` with `den.aspects.<name>.nixos = ...` and `den.aspects.nas.includes = [ den.aspects.<name> ];` in the same file. Inclusion is the enable gate. There is no `server` role aspect.
- Register web service data for backup in the owning aspect. Follow the [NAS backup contract](../backups/AGENTS.md).
- Declare secrets next to the consuming service, with quoted names for dashed keys.
- Never hardcode the domain, username, home path, email, LAN subnet or host addresses. Read `config.codyos.site`; name vhosts `"<name>.${domain}"` with `inherit (config.codyos.site) domain;` and use `mkNginxVhost`.
- Put cross-host proxy routes in the ingress layer. Register each Homepage card in the aspect that owns its reachable URL; cards are collected only on the host that includes them.
- Keep custom options under `codyos.*`/`nas.*`, not upstream namespaces, unless deliberately extending an upstream module.
- Upstream NixOS modules are imported by the one aspect that uses their options (`vpn-confinement` by `media`, `workflow` by `hermes-agent`), never at several sites.

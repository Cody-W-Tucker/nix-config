# Web apps and NAS ingress

`nginx.nix` provides `mkNginxVhost` on every host and the NAS ingress (`den.aspects.nginx.server`). Each other file is one self-hosted web app. These rules also apply to the other NAS service directories (`feeds/`, `observability/`, `backups/`, `ai/`, `documents/`, `media/`).

- Add a service as `modules/web/<name>.nix` with `den.aspects.<name>.nixos` and `den.aspects.nas.includes = [ den.aspects.<name> ];` in the same file.
- Name the vhost `"<name>.${domain}"` with `inherit (config.codyos.site) domain;` and build it with `mkNginxVhost`. Read every address, user and path from `config.codyos.site`.
- Register the service's data with the [NAS backup contract](../backups/AGENTS.md).
- Put cross-host proxy routes in the ingress. Register a Homepage card in the aspect that owns its URL; cards appear only on the host that includes them.
- Custom options go under `codyos.*` or `nas.*`, unless you are deliberately extending an upstream module.
- Import an upstream NixOS module only in the one aspect that uses it (`vpn-confinement` in `media`, `workflow` in `hermes-agent`).

# Network Services: DNS, AdGuard, and Syncthing

Server-owned network service notes now live in [`modules/server/README.md`](../modules/server/README.md#network-services).

Code owners:

- DNS filtering: [`modules/server/adguard.nix`](../modules/server/adguard.nix)
- Syncthing reverse proxy: [`modules/server/nginx-syncthing.nix`](../modules/server/nginx-syncthing.nix)
- Shared Syncthing service configuration, when needed: [`modules/services/`](../modules/services/)

Keep implementation detail local to the modules because DNS and sync changes affect the LAN directly.

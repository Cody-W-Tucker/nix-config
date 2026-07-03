# Server: Home Lab Server

The `server` host is the central `homehub.tv` service hub. It owns ingress, certificates, media services, personal data services, DNS filtering, Syncthing exposure, and observability.

Implementation detail now lives with the code in [`modules/server/README.md`](../modules/server/README.md). Use that file for the current module map, service ownership, storage layout, ingress rules, security notes, and change checklist.

Primary code entry points:

- [`hosts/server.nix`](../hosts/server.nix)
- [`modules/server/default.nix`](../modules/server/default.nix)
- [`modules/server/`](../modules/server/)

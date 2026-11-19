# llama-swap Service

Owns the NixOS integration for local llama-swap serving.

Does not own model files, user chat clients, Hermes identity, or general desktop AI tooling.

## Placement Rules

- Keep service wiring, ports, users, environment, and systemd behavior here.
- Keep model selection explicit and avoid hidden mutable defaults.
- Put secrets next to the service and use SOPS for private values.
- Keep client/editor/Hermes integration outside this module unless it is required service plumbing.
- Prefer small support files over embedding long scripts in `default.nix`.

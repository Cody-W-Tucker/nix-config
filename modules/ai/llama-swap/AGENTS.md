# llama-swap Service

Owns the NixOS integration for local llama-swap serving on the NAS, the only host that runs local models. Write it as NAS configuration, not as a reusable module: set llama-swap's own `settings` directly and use plain `let` bindings, not new options.

Does not own user chat clients, Hermes identity, or general desktop AI tooling.

## Layout

| File | Owns |
| --- | --- |
| `llama-swap.nix` | The aspect: service, llama-server command rendering, routing sets, systemd, firewall, backups, Homepage card |
| `_models.nix` | GGUF models: download pin and llama-server flags per model |
| `_audio.nix` | Speech models served by helper servers, and the speech-history service |
| `_laya.nix` | Laya gateway, Vega worker, training timer, and the `services.laya` options Karakeep triage reads |
| `_classifiers.nix` | Laya classifier definitions |
| `_endpoint.nix` | Host and ports, also read by beast's clients |

## Placement Rules

- Keep model selection explicit and avoid hidden mutable defaults.
- Put secrets next to the service and use SOPS for private values.
- Keep client/editor/Hermes integration outside this module unless it is required service plumbing.
- Keep long scripts in their own files next to the Nix that runs them.
- A multimodal model must set `mmprojFile` to its matching projector, or llama-server rejects image input.
- Keep tuning benchmarks in Hindsight (`codyos` bank, tag `llama-swap`), not in comments. The constraints themselves are `source-note` memories in the same bank.

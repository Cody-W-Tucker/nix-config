# llama-swap

Local model serving on the NAS, the only host that runs models, plus beast's dictation client. Write it as NAS configuration: set llama-swap's own `settings` directly with plain `let` bindings, not new options.

| File | Owns |
| --- | --- |
| `llama-swap.nix` | The aspect: service, llama-server command rendering, routing sets, systemd, firewall, backups, Homepage card |
| `_models.nix` | GGUF models: download pin and llama-server flags per model |
| `_audio.nix` | Speech models on helper servers, and the speech-history service |
| `_laya.nix` | Laya gateway, Vega worker, training timer, and the `services.laya` options Karakeep triage reads |
| `_classifiers.nix` | Laya classifier definitions |
| `_endpoint.nix` | Host and ports, also read by beast's clients |
| `dictation.nix`, `dictation.sh` | `llama-swap.dictation`: beast's `llama-dictate` (record, transcribe, clean up with s1-mini, type, fix) |

- Select models explicitly; no hidden mutable defaults.
- Chat clients, editors and Hermes integrate from their own aspects, unless they exist only as clients of this endpoint, like dictation.
- A multimodal model must set `mmprojFile` to its matching projector, or llama-server rejects image input.
- Tuning benchmarks are in Hindsight (bank `codyos`, tag `llama-swap`).

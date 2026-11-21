# check-imports

Run by `update` and by `nix flake check` (`checks.x86_64-linux.imports`, see
`modules/flake/checks.nix`). Usage: `check-imports [repo-root]` (default `/etc/nixos`).

Two rules:

1. **Sibling imports.** In every directory with a `default.nix`, each sibling `.nix`
   file must be referenced as `./name.nix` in that `default.nix`, and every `./name.nix`
   it references must exist. This only matters in `_` subtrees (plain NixOS or Home
   Manager module trees such as `modules/harness/_hm/`), the only place `default.nix`
   is allowed.
2. **Den layout.** No `default.nix` under `modules/` outside a `_` path. Every
   non-underscore `.nix` under `modules/` is loaded by import-tree as a flake-level Den
   module; see `modules/AGENTS.md`.

# Repository layout

- [`flake.nix`](./flake.nix) — flake inputs and the one `evalModules` call that turns `modules/` into the flake outputs.
- [`modules/`](./modules) — the [Den](https://github.com/denful/den) tree, loaded by import-tree: [`hosts/`](./modules/hosts) (beast, nas), shared aspects ([`nix/`](./modules/nix), [`shell/`](./modules/shell), [`networking/`](./modules/networking), [`observability/`](./modules/observability), [`hardware/`](./modules/hardware), [`users/`](./modules/users)), [`desktop/`](./modules/desktop), [`editor/`](./modules/editor), [`harness/`](./modules/harness), [`services/`](./modules/services), [`server/`](./modules/server) (NAS services) and [`flake/`](./modules/flake) (overlay, packages, checks, formatter). See [`modules/README.md`](./modules/README.md).
- [`packages/`](./packages) — custom packages and scripts, exposed through the shared overlay.
- [`docs/`](./docs) — longer operator notes and system-specific reference material; start with [`docs/Den-Native-Layout.md`](./docs/Den-Native-Layout.md).

# Repository layout

- [`flake.nix`](./flake.nix) — flake entry point and output assembly.
- [`hosts/`](./hosts) — machine-specific composition and hardware facts.
- [`modules/`](./modules) — reusable NixOS modules for services, desktop plumbing, hardware support, and shared system behavior.
- [`users/`](./users) — Home Manager profiles and user-session configuration.
- [`docs/`](./docs) — longer operator notes and system-specific reference material.

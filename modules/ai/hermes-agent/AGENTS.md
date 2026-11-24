# Hermes on the NAS

`hermes-agent.nix` owns the Den aspect and backups. `_nixos/default.nix`
wraps the pinned upstream NixOS module. QMD runs as Cody via `_bridge/`;
`_nixos/mcp/` runs read-only deja search as Cody with the `hermes` group.
Neither mounts his home into Hermes. Do not reintroduce a Home Manager gateway
or dashboard.

- `services.hermes-agent.stateDir` belongs to the `hermes` system user.
  Upstream installs `config.yaml` and `.env` into `${stateDir}/.hermes` at
  activation; put lasting settings in Nix, not in that file at runtime.
- `runtime/`, `secrets/`, and `plugins/` own unit, secret and plugin wiring.
  `documents/` compiles the living SOUL before startup; do not also install
  `SOUL.md` via `hermesHomeFiles`.
- `skills/` separates declarative external skill packs from mutable seeded
  skills. `toolsets/` limits what each platform sees, not what the OS permits.
- `plugins/bubblewrap/` controls terminal mounts and `egress/` controls the
  system user's network access. Add terminal mounts through
  `codyos.hermes-agent.sandbox.binds`; upstream replaces rather than merges
  lists in `settings`. Check the system units as well as the terminal when
  changing a trust boundary: MCP, gateway tools and cron are not all terminal
  commands.

Check Den routing and merged settings before debugging the live service.
Gateway and dashboard diagnostics use system `journalctl`, not `--user`.

# Obsidian via Home Manager

Cody's declarative Obsidian config: vaults, shared settings, plugins, plugin settings, hotkeys and snippets. Note content and app-written vault state are not managed here.

- Shared defaults and vault helpers go in `default.nix`, shared hotkeys in `hotkeys.nix`, CSS snippets in `snippets/`, preserved plugin JSON in `plugin-data/`. Vault-only files go in that vault's `extraFiles`.
- Keep each vault block to its real differences; prefer shared config when a behavior suits more than one vault.
- Bring app-written state into Nix only when it records durable intent, reduced to the smallest setting that reproduces it.
- Do not move vault paths or note formats; agent workflows depend on them.
- Nested settings such as `vimMode` are freeform keys missing from the `programs.obsidian` option index; copy existing patterns here.

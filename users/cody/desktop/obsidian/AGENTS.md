# Obsidian Via Home Manager

Owns Cody's declarative Obsidian Home Manager configuration: vault definitions, shared app settings, plugins, plugin settings, hotkeys, snippets, and desktop launch integration.

Does not own note content, generated vault state, or general knowledge-base agent behavior outside the Obsidian app configuration.

## Placement Rules

- Put shared app defaults and shared vault helpers in `default.nix`.
- Keep vault blocks small and limited to real vault-specific differences.
- Put shared hotkeys in `hotkeys.nix`.
- Put shared CSS snippets in `snippets/` and reference them from the shared snippet list.
- Put preserved plugin JSON under `plugin-data/` and load it from Nix.
- Put vault-only JSON files in that vault's `extraFiles`.

## Heuristics

- Prefer shared configuration when a behavior should apply to more than one vault.
- Promote app-written state into Nix only when it captures durable intent.
- Translate noisy UI-generated JSON into the smallest stable config needed to reproduce the behavior.
- If two approaches work, prefer the one that leaves fewer per-vault differences behind.

## Failure Modes

- Each vault becomes a full fork of shared behavior.
- Large generated JSON blobs are copied into Nix without identifying the setting that matters.
- Hotkeys, snippets, or common plugins drift across vaults.
- Vault paths or note formats move casually and break agent-facing workflows.

See `README.md` for structure, change procedures, and option-search notes.

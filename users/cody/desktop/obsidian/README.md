# Obsidian Home Manager Configuration

This directory contains Cody's declarative Obsidian configuration for Home Manager. It manages vault definitions, shared settings, plugins, plugin settings, hotkeys, CSS snippets, and the desktop entry for the primary vault.

## Structure

- `default.nix` — Obsidian package/config owner, shared settings, vault definitions, plugins, snippets, and desktop entry.
- `hotkeys.nix` — shared Obsidian hotkeys.
- `plugin-data/*.json` — preserved plugin settings loaded by Nix.
- `snippets/*.css` — shared CSS snippets.

## Vaults

- `~/Knowledge/Personal` — primary working vault.
- `~/Knowledge/Base` — lighter reference/base vault.

Shared settings live once in the Home Manager layer. Vault blocks contain path-specific or structure-specific differences such as local folders, templates, or files that only make sense in that vault.

## Shared vs. vault-specific settings

- Shared app defaults, common plugins, hotkeys, and snippets are represented in the shared settings/helpers in `default.nix`.
- Vault-specific settings live in the relevant vault block.
- Plugin settings that are naturally JSON live in `plugin-data/`.
- Vault-only JSON files are attached through that vault's `extraFiles`.

## Common changes

### Add a vault

Start from the existing vault pattern in `default.nix`, reuse the shared helpers, and add only the path and settings that describe that vault's structure.

### Change shared behavior

Change the shared settings/helper in `default.nix` when the behavior should apply to multiple vaults. Use a vault block only when the shared behavior would be wrong for that vault.

### Add or change plugins

Represent shared plugins in the shared plugin configuration. Store the smallest stable plugin settings needed to reproduce behavior under `plugin-data/`.

### Add snippets or hotkeys

Put CSS snippets in `snippets/` and hotkey changes in `hotkeys.nix`. Shared snippets are referenced from the shared snippet list in `default.nix`.

## Finding options

Use Home Manager option search to find the top-level Obsidian option surface:

```text
nixos-option-search_nix action=search source=home-manager type=options query="programs.obsidian"
```

This is useful for options such as:

- `programs.obsidian.defaultSettings.app`
- `programs.obsidian.defaultSettings.appearance`
- `programs.obsidian.defaultSettings.communityPlugins`
- `programs.obsidian.defaultSettings.cssSnippets`

Nested app keys such as `vimMode` are freeform settings inside generated Obsidian JSON payloads, not first-class indexed module options. For those, search this directory for the existing setting pattern.

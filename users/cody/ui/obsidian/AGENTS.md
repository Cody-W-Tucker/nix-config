# Obsidian Via Home Manager

Use this directory to keep Obsidian management easy to extend across multiple vaults.

The important path is:

- shared settings live once
- vault blocks stay small
- app-written state only gets promoted into Nix when it is worth sharing or preserving

That matters because the failure mode here is not "one setting is wrong". The failure mode is that each vault slowly becomes its own bespoke config and future changes get harder every time.

## What Matters

### Shared First

If a behavior should feel the same in more than one vault, put it in the shared Home Manager layer first.

This matters because shared defaults reduce drift.
Outcome: adding or changing vaults stays cheap.

### Vault Blocks Should Only Hold Real Differences

Use a vault's `settings` block for things that are truly tied to that vault's structure, such as note folders, templates, or files that only make sense there.

This matters because vault-specific config is the main source of duplication.
Outcome: each vault reads as "what is special here" instead of "a full fork of shared behavior".

### Translate Intent, Not Raw App State

When Obsidian writes JSON that seems useful, extract the underlying intent and model that in Nix rather than copying large chunks of generated config blindly.

This matters because app state is noisy and often includes details we do not want to maintain.
Outcome: smaller config, clearer diffs, and fewer accidental regressions.

### Centralize Ergonomics

Treat hotkeys, shared snippets, and common plugins as part of the platform for all vaults unless there is a concrete reason to narrow scope.

This matters because these are the highest-leverage pieces of Obsidian behavior.
Outcome: one change improves every relevant vault.

## How To Make Changes

### Adding A Vault

1. Start from the existing vault pattern in `default.nix`.
2. Reuse the shared helpers before adding anything vault-specific.
3. Add only the settings that describe that vault's actual structure.
4. Keep asking: can this move up into shared config instead?

Target outcome: a new vault block should be mostly path and a few local files, not a second full configuration system.

### Changing Shared Behavior

1. Look for the shared helper or shared settings area first.
2. Change the common source instead of patching multiple vaults.
3. Only push something down into a vault block if the shared version would be wrong there.

Target outcome: one edit changes the behavior everywhere it should.

### Adding Plugins

1. Decide whether the plugin is part of the shared Obsidian baseline or only useful in one vault.
2. If shared, manage it in the shared plugin configuration.
3. If it needs settings, check in the smallest stable settings data needed to reproduce the behavior.
4. Store plugin-owned JSON under `plugin-data/` rather than at the root of this directory.

Target outcome: plugins become reproducible building blocks rather than hidden UI state.

### Adding Snippets Or Hotkeys

1. Assume they are shared unless proven otherwise.
2. Keep snippet files small and purposeful.
3. Keep hotkey edits in the existing style rather than introducing new abstraction.

Target outcome: editing ergonomics stays obvious and future agents can make small changes safely.

## Placement Rules

- Shared app defaults belong in the shared settings area in `default.nix`.
- Shared vault behavior belongs in shared helpers in `default.nix`.
- Vault-only JSON files belong in that vault's `extraFiles`.
- Shared hotkeys belong in `hotkeys.nix`.
- Shared CSS belongs in `snippets/` and is then referenced from the shared snippet list.
- Plugin settings that need to be preserved belong in `plugin-data/` and should be loaded from Nix.

## Finding Settings

Use the Nix option search when you need to discover the Home Manager surface area for Obsidian.

Example:

```text
nixos-option-search_nix action=search source=home-manager type=options query="programs.obsidian"
```

That is good for finding top-level options such as:

- `programs.obsidian.defaultSettings.app`
- `programs.obsidian.defaultSettings.appearance`
- `programs.obsidian.defaultSettings.communityPlugins`
- `programs.obsidian.defaultSettings.cssSnippets`

Do not expect nested app keys like `vimMode` to appear there. Those live inside freeform settings payloads written into Obsidian JSON files.

For those, search the code in this directory instead.

This matters because it avoids getting stuck searching the option index for values that are not modeled as first-class module options.
Outcome: use the option search to find the entry point, then use code search to find the actual nested setting pattern.

## Heuristics For Difficult Requests

When a request is vague, default to these questions internally:

- Is this meant to help one vault, or define the baseline for many?
- Is this a durable rule, or just app state we noticed once?
- Can this be expressed by extending an existing shared helper instead of adding a new path?
- What is the smallest change that keeps future vaults easier to manage?

If two approaches both work, prefer the one that leaves less config behind.

## What Good Looks Like

- Shared behavior is easy to locate.
- Vault differences are obvious.
- New vaults mostly compose existing pieces.
- UI discoveries get translated back into declarative config when they are worth keeping.
- Future changes require editing one place more often than many places.

Keep this file updated as the Obsidian Home Manager structure changes so the workflow guidance continues to match how this directory is actually organized.

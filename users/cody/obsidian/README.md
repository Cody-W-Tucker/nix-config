# Obsidian Declarative Configuration

This directory contains the declarative NixOS/Home Manager configuration for Obsidian.

## Structure

- `default.nix` - Main Home Manager Obsidian config
- `hotkeys.nix` - Hotkey definitions
- `snippets/` - CSS snippets referenced directly by Home Manager
- `plugins.nix` - Community plugin packages (optional, needs actual hashes)
- `themes/` - Theme files copied from your existing vault

## Current Configuration

### Vault Layout
- `Personal` carries the daily-notes config, FastPpuccin theme, and its existing custom hotkeys.
- `Base` keeps its own app and appearance settings and does not inherit `Personal` daily-note files.

### Enabled Core Plugins
- file-explorer, global-search, switcher
- graph, backlink, outgoing-link
- tag-pane, properties
- daily-notes, templates, note-composer
- command-palette, outline, word-count
- webviewer, bases

### Disabled Core Plugins
- canvas, page-preview, slash-command
- editor-status, bookmarks, markdown-importer
- zk-prefixer, random-note, slides
- audio-recorder, workspaces, file-recovery
- publish, sync, footnotes

### Themes
- **Active**: FastPpuccin (v1.1.4) - High-performance AnuPpuccin clone

### CSS Snippets (Enabled)
- `mermaid` - Makes mermaid diagrams 100% width
- `tables` - Forces tables to expand instead of scroll
- `print` - Print media queries

### Notes
- The configuration now leans on Home Manager's shorthand forms: plugin names are plain strings, snippets are plain `.css` paths, and themes are plain packages.

### Hotkeys
- `Mod +` - Insert template
- `Mod H` - Toggle highlight
- `Mod Shift F` - Open search and replace
- `Mod Escape` - Toggle fold properties
- `Mod Shift P` - Command palette
- `Mod P` - Switcher (quick file open)
- `Mod M` - Move file
- `Mod Shift M` - Merge file
- `Mod Shift D` - Delete file
- `Alt Tab` - Toggle left sidebar
- `Alt Escape` - Toggle right sidebar

### Daily Notes Configuration
- Format: `YYYY/MM-MMMM/YYYY-MM-DD-dddd`
- Folder: `Journal`
- Template: `Admin/Note Templates/daily`

### Templates Configuration
- Folder: `Admin/Note Templates`
- Date format: `YYYY/MM-MMMM/YYYY-MM-DD-dddd`

## Community Plugins (Not yet migrated)

Your current vault has these community plugins installed:

1. obsidian-linter
2. obsidian-rollover-daily-todos
3. obsidian-textgenerator-plugin
4. obsidian-style-settings
5. smart-connections-visualizer
6. smart-connections
7. templater-obsidian
8. sync-graph-settings
9. obsidian-local-rest-api
10. tray
11. calendar
12. obsidian-git
13. obsidian-excalidraw-plugin
14. periodic-notes
15. novel-word-count

### Migration Options for Community Plugins

**Option 1: Manual packaging (recommended for a fully declarative setup)**

Edit `plugins.nix` and add proper `fetchFromGitHub` calls with real sha256 hashes for each plugin you want to manage declaratively. Example structure is already provided in the file.

**Option 2: Use existing plugin files (simplest migration)**

Keep your existing `.obsidian/plugins/` directory as-is. The plugins will continue to work but won't be managed declaratively.

**Option 3: Hybrid approach**

Package the most important plugins (like obsidian-git, templater) declaratively, leave the rest as-is.

## Migration Steps

1. **Backup your vault**: Make sure your `~/Knowledge/Personal` vault is backed up

2. **Add to your home configuration**: Import this module in your `ui.nix`:
   ```nix
   imports = [
     ./obsidian
     ./ui
     ./cli
     ./agent
     ./packages/scripts
   ];
   ```

3. **Copy theme files**: Copy the theme directory from your vault:
   ```bash
    mkdir -p /etc/nixos/users/cody/obsidian/themes/FastPpuccin
    cp ~/Knowledge/Personal/.obsidian/themes/FastPpuccin/theme.css /etc/nixos/users/cody/obsidian/themes/FastPpuccin/
    cp ~/Knowledge/Personal/.obsidian/themes/FastPpuccin/manifest.json /etc/nixos/users/cody/obsidian/themes/FastPpuccin/
   ```

4. **Test the build**:
   ```bash
   nixos-rebuild dry-run --flake .  # or nixos-rebuild switch --flake .
   ```

5. **Handle existing .obsidian directory**: Once you activate the new configuration, you have two options:

   **Option A - Remove existing config (full declarative)**:
   ```bash
   mv ~/Knowledge/Personal/.obsidian ~/Knowledge/Personal/.obsidian.backup
   ```
   Then let home-manager create the new declarative configuration.

   **Option B - Keep existing config (partial migration)**:
   Keep the existing `.obsidian` directory. Home-manager will create symlinks for the declarative parts, but you'll need to manually manage conflicts.

## Troubleshooting

### Theme not applying
Make sure the theme files are copied to `themes/FastPpuccin/` in this directory.

### Plugins not loading
The home-manager obsidian module has had issues with community plugins in the past. Check the home-manager GitHub issues for the latest status. You may need to manually install community plugins through Obsidian's interface.

### Configuration conflicts
If you have both the declarative config and existing `.obsidian` files, Obsidian may show conflicts. The declarative configuration takes precedence for files managed by home-manager.

## References

- [Home Manager Obsidian Module](https://github.com/nix-community/home-manager/blob/master/modules/programs/obsidian.nix)
- [Obsidian Help](https://help.obsidian.md/)
- [FastPpuccin Theme](https://github.com/LostViking09/obsidian-fastppuccin)

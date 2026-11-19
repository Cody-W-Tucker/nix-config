# Theming and Styling (Stylix)

The CodyOS theming architecture is powered by **Stylix**, a declarative theming layer that feeds colors, fonts, cursor settings, and related desktop styling into Home Manager applications and desktop configuration.

## Where To Look

- `modules/desktop/theming.nix`: the `theming` aspect (Home Manager only): Stylix enablement, base16 scheme, GTK icon override, and shared desktop theme settings such as polarity, opacity, cursor, fonts, wallpaper, and target overrides [modules/desktop/theming.nix](../modules/desktop/theming.nix)
- `modules/desktop/fonts.nix`: system-level font availability for the desktop profile (beast only; the headless NAS installs no fonts) [modules/desktop/fonts.nix](../modules/desktop/fonts.nix)

## Configuration Split

The main thing to know is that the desktop theming surface is split across two layers:

- `modules/desktop/theming.nix` is the `theming` aspect, delivered to the user through `provides.to-users.homeManager`; it owns the shared Stylix settings and imports the Stylix Home Manager module, so `config.lib.stylix` exists only where the desktop is installed.
- Consumers elsewhere guard on it: `modules/users/shell.nix` (yazi, fzf) checks `config.lib ? stylix`; `modules/desktop/_waybar/waybar.nix` and `modules/desktop/_hyprland/settings.nix` read the colors directly.

## Application Integration and Data Flow

Stylix values are injected into application configurations through the `config.lib.stylix.colors` attribute set. This allows for dynamic theming of tools that do not natively support Stylix or require custom logic.

### Implementation Diagram: Color Injection

The following diagram illustrates how the `base16Scheme` is processed by Stylix and distributed to specific application configurations.

Title: Stylix Color Distribution Flow

```mermaid
flowchart LR
    C1["Git Status Colors"]
    D1["FZF UI Elements"]
    E1["Zsh Highlight"]
    subgraph subGraph1 ["Application Injection"]
        C["yazi/init.lua"]
        D["fzf/colors"]
        E["zsh/autosuggestion"]
        F["Hyprland/Borders"]
    end
    subgraph subGraph0 ["Stylix Engine"]
        A["base16-schemes/catppuccin-mocha.yaml"]
        B["config.lib.stylix.colors"]
    end
    A --> B
    B --> C
    B --> D
    B --> E
    B --> F
    C --> C1
    D --> D1
    E --> E1
```

### Specific Integrations

#### 1. Yazi (File Manager)

Yazi uses Stylix colors to theme its Git integration via custom Lua initialization. Colors are mapped from the base16 palette to specific Git states:

- **Modified**: `base0A` (Yellow) [modules/users/shell.nix](../modules/users/shell.nix)
- **Added**: `base0B` (Green) [modules/users/shell.nix](../modules/users/shell.nix)
- **Deleted**: `base08` (Red) [modules/users/shell.nix](../modules/users/shell.nix)
- **Untracked**: `base0C` (Cyan) [modules/users/shell.nix](../modules/users/shell.nix)

#### 2. FZF (Fuzzy Finder)

The Stylix `fzf` target is disabled (`stylix.targets.fzf.enable = false` in [modules/desktop/theming.nix](../modules/desktop/theming.nix)); `programs.fzf.colors` in `modules/users/shell.nix` sets the palette itself from `config.lib.stylix.colors`, guarded by `lib.mkIf (config.lib ? stylix)` so hosts without Stylix skip it:

- `fg+` (Current match) and `pointer` use `base0D` [modules/users/shell.nix](../modules/users/shell.nix)
- `prompt` uses `base03` [modules/users/shell.nix](../modules/users/shell.nix)

#### 3. Terminal and Shell

- **Kitty**: Automatically themed by Stylix, with a specific override in the desktop role [modules/desktop/theming.nix](../modules/desktop/theming.nix)
- **Zsh**: The `autosuggestion.highlight` uses the Stylix palette directly [modules/desktop/theming.nix](../modules/desktop/theming.nix)

## UI Component Configuration

Title: Desktop UI Component Mapping

```mermaid
flowchart LR
    subgraph subGraph2 ["Code Entities"]
        HYP_CODE["modules/desktop/hyprland.nix"]
        WB_CODE["modules/desktop/_waybar/waybar.nix"]
        PROG_CODE["modules/users/shell.nix"]
    end
    subgraph subGraph1 ["Visual Components"]
        HYP["Hyprland"]
        WB["Waybar"]
        BAT["Bat / Delta"]
    end
    subgraph subGraph0 ["Desktop Environment"]
        HM["Home Manager"]
        ST["Stylix Module"]
        COLORS["config.lib.stylix.colors"]
    end
    HM --> ST
    ST --> COLORS
    COLORS --> HYP
    COLORS --> WB
    COLORS --> BAT
    HYP -.-> HYP_CODE
    WB -.-> WB_CODE
    BAT -.-> PROG_CODE
```

### Manual Overrides and Exceptions

While Stylix manages most of the environment, certain applications are excluded or handled manually:

- **NixVim**: Stylix integration is disabled (`nixvim.enable = false`) to allow the editor's internal Catppuccin theme to handle specialized syntax highlighting [modules/desktop/theming.nix](../modules/desktop/theming.nix)
- **GTK**: Icons are manually set to the Adwaita theme rather than letting Stylix determine the icon pack [modules/desktop/theming.nix](../modules/desktop/theming.nix)
- **Waybar, Hyprlock, FZF**: Stylix targets are disabled because local config fully replaces them (`modules/desktop/_waybar/waybar.nix`, `modules/desktop/_hyprland/settings.nix`, `modules/users/shell.nix`) [modules/desktop/theming.nix](../modules/desktop/theming.nix)
- **Rofi**: Stylix still supplies colors, but its font is disabled (`rofi.fonts.enable = false`) because `modules/desktop/rofi.nix` sets its own [modules/desktop/theming.nix](../modules/desktop/theming.nix)
- **Dconf**: The GNOME target is disabled, so `modules/desktop/theming.nix` sets the desktop color-scheme preference from Stylix polarity directly for applications that follow the system preference.

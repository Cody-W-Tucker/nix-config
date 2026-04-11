{
  config,
  lib,
  pkgs,
  ...
}:

let
  sharedSnippets = [
    ./snippets/mermaid.css
    ./snippets/tables.css
    ./snippets/print.css
  ];

  obsidianLinterPlugin = pkgs.fetchzip {
    url = "https://github.com/platers/obsidian-linter/releases/download/1.30.0/obsidian-linter.zip";
    hash = "sha256-GlfRvFoH33W8T1I3hiZmZHzy99DazJRMgu13ufIOoyg=";
  };

  withSharedSnippets =
    settings:
    lib.mkMerge [
      {
        cssSnippets = lib.mkBefore sharedSnippets;
      }
      settings
    ];

  sharedCorePlugins = [
    "file-explorer"
    "global-search"
    "switcher"
    "graph"
    "backlink"
    "outgoing-link"
    "tag-pane"
    "properties"
    "daily-notes"
    "templates"
    "command-palette"
    "bases"
    "webviewer"
  ];
in
{
  stylix.targets.obsidian = {
    vaultNames = [
      "Personal"
      "Base"
    ];

    fonts.override.sizes.applications = 16;
  };

  programs.obsidian = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.obsidian;
    cli.enable = true;

    defaultSettings = {
      app = {
        propertiesInDocument = "hidden";
        promptDelete = false;
        trashOption = "none";
        showInlineTitle = false;
        vimMode = true;
      };

      corePlugins = sharedCorePlugins;
      communityPlugins = [
        {
          pkg = obsidianLinterPlugin;
          settings = builtins.fromJSON (builtins.readFile ./plugin-data/obsidian-linter-data.json);
        }
      ];
      cssSnippets = sharedSnippets;
      hotkeys = import ./hotkeys.nix;
    };

    vaults = {
      Personal = {
        target = "/home/codyt/Knowledge/Personal";
        settings = withSharedSnippets {
          extraFiles = {
            "daily-notes.json".text = builtins.toJSON {
              format = "YYYY/MM-MMMM/YYYY-MM-DD-dddd";
              template = "Admin/Note Templates/daily";
              folder = "Journal";
            };

            "templates.json".text = builtins.toJSON {
              folder = "Admin/Note Templates";
              dateFormat = "YYYY/MM-MMMM/YYYY-MM-DD-dddd";
            };
          };
        };
      };
      Base = {
        target = "/home/codyt/Knowledge/Base";
        settings = withSharedSnippets { };
      };
    };
  };
}

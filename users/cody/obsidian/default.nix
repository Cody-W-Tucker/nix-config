{
  config,
  pkgs,
  ...
}:

let
  fastPpuccin = pkgs.runCommand "fastppuccin-theme" { } ''
    mkdir -p $out
    cp ${./themes/FastPpuccin/theme.css} $out/theme.css
    cp ${./themes/FastPpuccin/manifest.json} $out/manifest.json
  '';

  sharedSnippets = [
    ./snippets/mermaid.css
    ./snippets/tables.css
    ./snippets/print.css
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
    "note-composer"
    "command-palette"
    "outline"
    "word-count"
    "bases"
    "webviewer"
  ];
in
{
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
      };

      corePlugins = sharedCorePlugins;
      cssSnippets = sharedSnippets;
      themes = [ fastPpuccin ];
      hotkeys = import ./hotkeys.nix;
    };

    vaults = {
      Personal = {
        target = "/home/codyt/Knowledge/Personal";
        settings = {
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
      };
    };
  };
}

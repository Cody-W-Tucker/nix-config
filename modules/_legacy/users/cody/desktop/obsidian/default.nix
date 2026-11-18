{
  config,
  lib,
  pkgs,
  ...
}:

let
  sharedSnippets = [
    ./snippets/mermaid.css
    ./snippets/hide-inactive-comments.css
    ./snippets/tables.css
    ./snippets/print.css
  ];

  obsidianLinterPlugin = pkgs.fetchzip {
    url = "https://github.com/platers/obsidian-linter/releases/download/1.30.0/obsidian-linter.zip";
    hash = "sha256-GlfRvFoH33W8T1I3hiZmZHzy99DazJRMgu13ufIOoyg=";
  };

  # Fetch a community plugin from its GitHub release assets.
  mkReleasePlugin =
    {
      owner,
      repo,
      version,
      files,
    }:
    pkgs.runCommand "${repo}-${version}" { } (
      ''
        mkdir -p $out
      ''
      + lib.concatMapStrings (file: ''
        cp ${
          pkgs.fetchurl {
            url = "https://github.com/${owner}/${repo}/releases/download/${version}/${file}";
            hash = files.${file};
          }
        } $out/${file}
      '') (builtins.attrNames files)
    );

  obsidianTrayPlugin = mkReleasePlugin {
    owner = "dragonwocky";
    repo = "obsidian-tray";
    version = "0.3.5";
    files = {
      "main.js" = "sha256-BHGlkLij4wgpP10upwgFN3rBVmBTcoVl1j6ktVCUrUI=";
      "manifest.json" = "sha256-gOjuAtf7mcgrlH162TrC37BmP0hQthSMfeOAN+/kSjQ=";
    };
  };

  obsidianAutoDailyNotePlugin = mkReleasePlugin {
    owner = "litegral";
    repo = "auto-daily-note";
    version = "1.0.0";
    files = {
      "main.js" = "sha256-GhXQ8oQGWrgyHJb+uVBlQW3XP3IohBwAedSuVuKQkZ0=";
      "manifest.json" = "sha256-eZwUnAItdSKr/LBy3xkWiRhw5QGJJRh/brGlzWP/iy4=";
    };
  };

  obsidianRolloverDailyTodosPlugin = mkReleasePlugin {
    owner = "lumoe";
    repo = "obsidian-rollover-daily-todos";
    version = "1.2.0";
    files = {
      "main.js" = "sha256-TwgpNjyVgHnqAioVScLq59iB4axgpB3x/I7J/9m8Ock=";
      "manifest.json" = "sha256-m1JvPjwSFF3kKAlils5gFbztfGK6kQpbC3kDQMUQH8E=";
      "versions.json" = "sha256-8oIWEqT4PYeeIyhVzLqSUNpp4SSK19GlAuo52RRD8gs=";
    };
  };

  obsidianGitPlugin = mkReleasePlugin {
    owner = "Vinzent03";
    repo = "obsidian-git";
    version = "2.41.1";
    files = {
      "main.js" = "sha256-KKGK/KsdLxUqDTyJr/OOKpetC+GuqvmWMGEyM7vsbBs=";
      "manifest.json" = "sha256-XU0PQRUYY2wdKkgxQlqONIe5JbW9QTvgyiLm3jilk/c=";
      "styles.css" = "sha256-v6j71F/kn/NA/bGWuEut1jGu3l1vlnQPM26nec1EEAU=";
    };
  };

  sharedCommunityPlugins = [
    {
      pkg = obsidianLinterPlugin;
      settings = builtins.fromJSON (builtins.readFile ./plugin-data/obsidian-linter-data.json);
    }
  ];

  # Stylix's obsidian target defines vault-level cssSnippets, which would
  # otherwise replace the shared defaults instead of extending them.
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
    "note-composer"
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
      communityPlugins = sharedCommunityPlugins;
      cssSnippets = sharedSnippets;
      hotkeys = import ./hotkeys.nix;
    };

    vaults = {
      Personal = {
        target = "${config.home.homeDirectory}/Knowledge/Personal";
        settings = withSharedSnippets {
          communityPlugins = sharedCommunityPlugins ++ [
            {
              pkg = obsidianTrayPlugin;
              settings = builtins.fromJSON (builtins.readFile ./plugin-data/tray-data.json);
            }
            {
              pkg = obsidianAutoDailyNotePlugin;
            }
            {
              pkg = obsidianRolloverDailyTodosPlugin;
              settings = builtins.fromJSON (builtins.readFile ./plugin-data/rollover-daily-todos-data.json);
            }
            {
              pkg = obsidianGitPlugin;
              settings = builtins.fromJSON (builtins.readFile ./plugin-data/obsidian-git-data.json);
            }
          ];

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
        target = "${config.home.homeDirectory}/Knowledge/Base";
        settings = withSharedSnippets { };
      };
    };
  };
}

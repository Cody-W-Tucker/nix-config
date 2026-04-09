let
  bind = modifiers: key: { inherit modifiers key; };
in
{
  "obsidian-excalidraw-plugin:insert-link-to-element" = [ ];
  "insert-template" = [ (bind [ "Mod" ] "+") ];
  "obsidian-textgenerator-plugin:text-extractor-tool" = [ (bind [ "Shift" ] "Escape") ];
  "obsidian-tasks-plugin:edit-task" = [ (bind [ "Mod" ] "`") ];
  "editor:toggle-highlight" = [ (bind [ "Mod" ] "H") ];
  "editor:open-search-replace" = [ (bind [ "Mod" "Shift" ] "F") ];
  "editor:toggle-fold-properties" = [ (bind [ "Mod" ] "Escape") ];

  "command-palette:open" = [ (bind [ "Mod" "Shift" ] "P") ];
  "switcher:open" = [ (bind [ "Mod" ] "P") ];
  "global-search:open" = [ ];

  "file-explorer:move-file" = [ (bind [ "Mod" ] "M") ];
  "note-composer:merge-file" = [ (bind [ "Mod" "Shift" ] "M") ];
  "obsidian-textgenerator-plugin:insert-generated-text-From-template" = [ (bind [ "Mod" ] "O") ];
  "app:delete-file" = [ (bind [ "Mod" "Shift" ] "D") ];
  "obsidian-focus-mode:toggle-focus-mode" = [ ];

  "app:toggle-left-sidebar" = [ (bind [ "Alt" ] "Tab") ];
  "app:toggle-right-sidebar" = [ (bind [ "Alt" ] "Escape") ];

  "templater-obsidian:jump-to-next-cursor-location" = [ ];
}

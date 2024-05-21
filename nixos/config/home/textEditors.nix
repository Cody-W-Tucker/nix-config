{ pkg, config, ... }: {

  programs.vscode = {
    enable = true;
    userSettings = {
      "workbench.colorCustomizations" = {
        "[Stylix]" = {
          "button.background" = "#${config.lib.stylix.colors.base0D}BB";
          "button.foreground" = "#${config.lib.stylix.colors.base06}";
          "button.secondaryBackground" = "#${config.lib.stylix.colors.base0E}BB";
          "button.secondaryForeground" = "#${config.lib.stylix.colors.base06}";
          "editor.selectionHighlightBackground" = "#${config.lib.stylix.colors.base04}EE";
          "editor.wordHighlightBackground" = "#${config.lib.stylix.colors.base01}00";
          "scrollbarSlider.activeBackground" = "#${config.lib.stylix.colors.base04}55";
          "scrollbarSlider.background" = "#${config.lib.stylix.colors.base03}55";
          "scrollbarSlider.hoverBackground" = "#${config.lib.stylix.colors.base04}99";
          "statusBar.background" = "#${config.lib.stylix.colors.base00}";
          "statusBar.noFolderBackground" = "#${config.lib.stylix.colors.base00}";
          "statusBar.noFolderForeground" = "#${config.lib.stylix.colors.base06}";
          "statusBarItem.remoteBackground" = "#${config.lib.stylix.colors.base00}";
        };
      };
    };
  };
}


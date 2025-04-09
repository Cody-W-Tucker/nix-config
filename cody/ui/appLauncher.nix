{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    extraConfig = {
      modi = "custom:web-search,drun";
      show-icons = true;
      icon-theme = "Papirus";
      location = 0;
      font = "JetBrains Nerd Font 16";
      drun-display-format = "{icon} {name}";
      display-drun = "";
      display-web-search = "";
      # display-filebrowser = "";
    };
    theme = let
        inherit (config.lib.formats.rasi) mkLiteral;
    in {
      "*" = {
        bg = mkLiteral "#${config.lib.stylix.colors.base00}";
        bg-alt = mkLiteral "#${config.lib.stylix.colors.base01}";
        selected = mkLiteral "#${config.lib.stylix.colors.base02}";
        active = mkLiteral "#${config.lib.stylix.colors.base0D}";
        text-selected = mkLiteral "#${config.lib.stylix.colors.base01}";
        text-color = mkLiteral "#${config.lib.stylix.colors.base05}";
        urgent = mkLiteral "#${config.lib.stylix.colors.base0E}";
      };
      "window" = {
        transparency = "real";
        width = mkLiteral "800px";
        height = mkLiteral "600px";
        location = mkLiteral "center";
        anchor = mkLiteral "center";
        fullscreen = false;
        x-offset = mkLiteral "0px";
        y-offset = mkLiteral "0px";
        cursor = "default";
        enabled = true;
        border-color = mkLiteral "@border-color";
        border-radius = mkLiteral "15px";
      };
      "mainbox" = {
        enabled = true;
        spacing = mkLiteral "0px";
        orientation = mkLiteral "horizontal";
        children = map mkLiteral [
          "imagebox"
          "listbox"
        ];
        background-color = mkLiteral "transparent";
      };
      "imagebox" = {
        padding = mkLiteral "20px";
        background-color = mkLiteral "transparent";
        background-image = mkLiteral ''url("/etc/nixos/modules/wallpapers/puffy-stars.jpg", width)'';
        orientation = mkLiteral "vertical";
        children = map mkLiteral [
          "inputbar"
          "dummy"
          "mode-switcher"
        ];
      };
      "listbox" = {
        spacing = mkLiteral "20px";
        padding = mkLiteral "20px";
        background-color = mkLiteral "transparent";
        orientation = mkLiteral "vertical";
        children = map mkLiteral [
          "message"
          "listview"
        ];
      };
      "dummy" = {
        background-color = mkLiteral "transparent";
      };
      "inputbar" = {
        enabled = true;
        spacing = mkLiteral "10px";
        padding = mkLiteral "10px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        children = map mkLiteral [
          "textbox-prompt-colon"
          "entry"
        ];
      };
      "textbox-prompt-colon" = {
        enabled = true;
        expand = false;
        str = "";
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };
      "entry" = {
        enabled = true;
        background-color = mkLiteral "inherit";
        cursor = mkLiteral "text";
        placeholder = "Search";
        placeholder-color = mkLiteral "inherit";
      };
      "mode-switcher" = {
        enabled = true;
        spacing = mkLiteral "20px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@foreground";
      };
      "button" = {
        padding = mkLiteral "15px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        cursor = mkLiteral "pointer";
      };
      "listview" = {
        enabled = true;
        columns = 1;
        lines = 8;
        cycle = true;
        dynamic = false;
        scrollbar = false;
        layout = mkLiteral "vertical";
        reverse = false;
        fixed-height = true;
        fixed-columns = true;
        spacing = mkLiteral "10px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@foreground";
        cursor = "default";
      };
      "element" = {
        enabled = true;
        spacing = mkLiteral "15px";
        padding = mkLiteral "8px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@text-color";
        cursor = mkLiteral "pointer";
      };
      "element selected" = {
        text-color = "@text-color";
      };
      "element-icon" = {
        text-color = mkLiteral "inherit";
        size = mkLiteral "36px";
        cursor = mkLiteral "inherit";
      };
      "element-text" = {
        text-color = mkLiteral "inherit";
        cursor = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.0";
      };
      "message" = {
        background-color = mkLiteral "transparent";
      };
      "textbox" = {
        padding = mkLiteral "15px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.0";
      };
      "error-message" = {
        padding = mkLiteral "15px";
        border-radius = mkLiteral "20px";
        background-color = mkLiteral "@bg";
        text-color = mkLiteral "@foreground";
      };
    };
  };
}

{ config, pkgs, lib, ... }:

{
  programs.rofi = {
    enable = true;
    plugins =[pkgs.rofi-calc];
    package = pkgs.rofi-wayland;
    extraConfig = {
      modi = "run,filebrowser,drun";
      show-icons = true;
      icon-theme = "Papirus";
      font = "JetBrains Nerd Font 16";
      drun-display-format = "{icon} {name}";
      display-drun = "   Apps ";
      display-run = "   Run ";
      display-filebrowser = "   File ";
    };
    theme = let
        inherit (config.lib.formats.rasi) mkLiteral;
    in {
      "*" = lib.mkForce {
        bg = mkLiteral "#${config.lib.stylix.colors.base00}";
        bg-alt = mkLiteral "#${config.lib.stylix.colors.base09}";
        foreground = mkLiteral "#${config.lib.stylix.colors.base01}";
        selected = mkLiteral "#${config.lib.stylix.colors.base08}";
        active = mkLiteral "#${config.lib.stylix.colors.base0B}";
        text-selected = mkLiteral "#${config.lib.stylix.colors.base00}";
        text-color = mkLiteral "#${config.lib.stylix.colors.base05}";
        border-color = mkLiteral "#${config.lib.stylix.colors.base0F}";
        urgent = mkLiteral "#${config.lib.stylix.colors.base0E}";
      };
      "window" = lib.mkForce {
        transparency = "real";
        width = mkLiteral "30%";
        location = mkLiteral "center";
        anchor = mkLiteral "center";
        fullscreen = false;
        x-offset = mkLiteral "0px";
        y-offset = mkLiteral "0px";
        cursor = "default";
        enabled = true;
        border-radius = mkLiteral "15px";
        background-color = mkLiteral "@bg";
      };
      "mainbox" = lib.mkForce {
        enabled = true;
        spacing = mkLiteral "0px";
        orientation = mkLiteral "horizontal";
        children = map mkLiteral [
          "imagebox"
          "listbox"
        ];
        background-color = mkLiteral "transparent";
      };
      "imagebox" = lib.mkForce {
        padding = mkLiteral "20px";
        background-color = mkLiteral "transparent";
        background-image = mkLiteral ''url("~/Pictures/Wallpapers/Rainnight.jpg", height)'';
        orientation = mkLiteral "vertical";
        children = map mkLiteral [
          "inputbar"
          "dummy"
          "mode-switcher"
        ];
      };
      "listbox" = lib.mkForce {
        spacing = mkLiteral "20px";
        padding = mkLiteral "20px";
        background-color = mkLiteral "transparent";
        orientation = mkLiteral "vertical";
        children = map mkLiteral [
          "message"
          "listview"
        ];
      };
      "dummy" = lib.mkForce {
        background-color = mkLiteral "transparent";
      };
      "inputbar" = lib.mkForce {
        enabled = true;
        spacing = mkLiteral "10px";
        padding = mkLiteral "10px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        text-color = mkLiteral "@foreground";
        children = map mkLiteral [
          "textbox-prompt-colon"
          "entry"
        ];
      };
      "textbox-prompt-colon" = lib.mkForce {
        enabled = true;
        expand = false;
        str = "";
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };
      "entry" = lib.mkForce {
        enabled = true;
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
        cursor = mkLiteral "text";
        placeholder = "Search";
        placeholder-color = mkLiteral "inherit";
      };
      "mode-switcher" = lib.mkForce {
        enabled = true;
        spacing = mkLiteral "20px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@foreground";
      };
      "button" = lib.mkForce {
        padding = mkLiteral "15px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        text-color = mkLiteral "inherit";
        cursor = mkLiteral "pointer";
      };
      "button selected" = lib.mkForce {
        background-color = mkLiteral "@selected";
        text-color = mkLiteral "@foreground";
      };
      "listview" = lib.mkForce {
        enabled = true;
        columns = 1;
        lines = 8;
        cycle = true;
        dynamic = true;
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
      "element" = lib.mkForce {
        enabled = true;
        spacing = mkLiteral "15px";
        padding = mkLiteral "8px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@text-color";
        cursor = mkLiteral "pointer";
      };
      "element normal.normal" = lib.mkForce {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "@text-color";
      };
      "element normal.urgent" = lib.mkForce {
        background-color = mkLiteral "@urgent";
        text-color = mkLiteral "@text-color";
      };
      "element normal.active" = lib.mkForce {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "@text-color";
      };
      "element selected.normal" = lib.mkForce {
        background-color = mkLiteral "@selected";
        text-color = mkLiteral "@foreground";
      };
      "element selected.urgent" = lib.mkForce {
        background-color = mkLiteral "@urgent";
        text-color = mkLiteral "@text-selected";
      };
      "element selected.active" = lib.mkForce {
        background-color = mkLiteral "@urgent";
        text-color = mkLiteral "@text-selected";
      };
      "element-icon" = lib.mkForce {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
        size = mkLiteral "36px";
        cursor = mkLiteral "inherit";
      };
      "element-text" = lib.mkForce {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
        cursor = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.0";
      };
      "message" = lib.mkForce {
        background-color = mkLiteral "transparent";
      };
      "textbox" = lib.mkForce {
        padding = mkLiteral "15px";
        border-radius = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        text-color = mkLiteral "@foreground";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.0";
      };
      "error-message" = lib.mkForce {
        padding = mkLiteral "15px";
        border-radius = mkLiteral "20px";
        background-color = mkLiteral "@bg";
        text-color = mkLiteral "@foreground";
      };
    };
  };
}

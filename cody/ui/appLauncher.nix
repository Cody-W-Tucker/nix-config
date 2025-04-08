{ lib, config, pkgs, ... }:

{
  programs.rofi.plugins =[pkgs.rofi-calc];
  home.file.".config/rofi/config.rasi".text = lib.mkForce ''
    @theme "/dev/null"

    * {
      bg: #${config.lib.stylix.colors.base00};
      background-color: @bg;
    }

    configuration {
      modi:		    "run,filebrowser,drun";
      show-icons:	    true;
      icon-theme:	    "Papirus";
      location:		    0;
      font:		    "JetBrains Nerd Font 16";	
      drun-display-format:  "{icon} {name}";
      display-drun:	    "   Apps ";
      display-run:	    "   Run ";
      display-filebrowser:  "   File ";
    }

    window { 
      width: 30%;
      transparency: "real";
      orientation: vertical;
      border: 2px ;
      border-color: #${config.lib.stylix.colors.base0F};
      border-radius: 10px;
    }

    mainbox {
      children: [ inputbar, listview, mode-switcher ];
    }

    // ELEMENT
    // -----------------------------------

    element {
      padding: 8 14;
      text-color: #${config.lib.stylix.colors.base05};
      border-radius: 5px;
    }

    element selected {
      text-color: #${config.lib.stylix.colors.base01};
      background-color: #${config.lib.stylix.colors.base0C};
    }

    element-text {
      background-color: inherit;
      text-color: inherit;
    }

    element-icon {
      size: 24 px;
      background-color: inherit;
      padding: 0 6 0 0;
      alignment: vertical;
    }

    listview {
      columns: 1;
      lines: 9;
      padding: 8 0;
      fixed-height: true;
      fixed-columns: true;
      fixed-lines: true;
      border: 0 10 6 10;
    }

    // INPUT BAR 
    //------------------------------------------------

    entry {
      text-color: #${config.lib.stylix.colors.base05};
      padding: 10 10 0 0;
      margin: 0 -2 0 0;
    }

    inputbar {
      padding: 20 0 0;
      margin: 0 0 0 0;
    } 

    prompt {
      text-color: #${config.lib.stylix.colors.base0D};
      padding: 10 6 0 10;
      margin: 0 -2 0 0;
    }

    // Mode Switcher
    //------------------------------------------------

    mode-switcher {
      border-color:   #${config.lib.stylix.colors.base0F};
      spacing:	      0;
    }

    button {
      padding:	      10px;
      background-color: @bg;
      text-color:	      #${config.lib.stylix.colors.base03};
      vertical-align:   0.5; 
      horizontal-align: 0.5;
    }

    button selected {
      background-color: @bg;
      text-color: #${config.lib.stylix.colors.base0F};
    }

    message {
      background-color: @bg;
      margin: 2px;
      padding: 2px;
      border-radius: 5px;
    }

    textbox {
      padding: 6px;
      margin: 20px 0px 0px 20px;
      text-color: #${config.lib.stylix.colors.base0F};
      background-color: @bg;
    }
  '';
}

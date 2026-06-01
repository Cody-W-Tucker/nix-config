{ config, ... }:

let
  colors = config.lib.stylix.colors;
in

{
  imports = [ ./module.nix ];

  programs.herdr = {
    enable = true;
    onboarding = false;
    theme = "terminal";
    showAgentLabelsOnPaneBorders = true;
    toastDelivery = "herdr";
    enableSound = false;
    resumeAgentsOnRestore = true;
    settings = {
      theme.custom = {
        # Map Herdr's smaller palette to Stylix's base16 guide.
        panel_bg = "#${colors.base00}";
        surface0 = "#${colors.base01}";
        surface1 = "#${colors.base02}";
        surface_dim = "#${colors.base01}";

        text = "#${colors.base05}";
        subtext0 = "#${colors.base04}";
        overlay0 = "#${colors.base03}";
        overlay1 = "#${colors.base04}";

        accent = "#${colors.base0D}";
        mauve = "#${colors.base0E}";
        green = "#${colors.base0B}";
        yellow = "#${colors.base0A}";
        red = "#${colors.base08}";
        blue = "#${colors.base0D}";
        teal = "#${colors.base0C}";
        peach = "#${colors.base09}";
      };
    };
  };
}

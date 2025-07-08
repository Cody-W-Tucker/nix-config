{ pkgs, ... }:

{
  imports = [
    ./cli
  ];

  config = {

    # Keyboard
    home.keyboard = {
      layout = "us";
      model = "pc105";
    };
    # Set the color theme
    home-manager.users.codyt.stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "24.05";
  };
}

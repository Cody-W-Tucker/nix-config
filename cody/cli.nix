{ pkgs, config, inputs, lib, ... }:

{
  imports = [
    ./cli
  ];

  # Keyboard
  home.keyboard = {
    layout = "us";
    model = "pc105";
  };

  home.sessionVariables = {
    VISUAL = "nvim";
    TERMINAL = "kitty";
  };

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}

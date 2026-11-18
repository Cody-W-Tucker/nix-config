# Desktop fonts. fontDir also sets the Xwayland default core-font path.

{ pkgs, ... }:

{
  fonts = {
    fontDir.enable = true;
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      font-awesome
      nerd-fonts.meslo-lg
      nerd-fonts.jetbrains-mono
    ];
  };
}

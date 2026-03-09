# System-wide fonts configuration

{ pkgs, ... }:

{
  fonts = {
    fontDir.enable = true;
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      font-awesome
      source-han-sans
      nerd-fonts.meslo-lg
      nerd-fonts.jetbrains-mono
    ];
  };
}

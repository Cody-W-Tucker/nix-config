# Discord configuration for NixOS
{ inputs, ... }:
{
  programs.nixcord = {
    enable = true;
    vesktop.enable = true;
    config = {
      frameless = true;
    };
  };
}

{ pkgs, ... }:
{
  # Machine specific packages
  environment.systemPackages = with pkgs; [
    rofi-network-manager
  ];
}

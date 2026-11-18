# Base system packages

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    btop
    wget
  ];
}

# Base system packages

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    nixpkgs-fmt
    starship
    btop
    wget
    borgbackup
  ];
}

{ pkgs, config, lib, ... }: {

  imports = [
    ./services.nix
    ./printers.nix
  ];

}

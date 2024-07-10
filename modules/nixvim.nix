{ config, nixvim, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
  };
}

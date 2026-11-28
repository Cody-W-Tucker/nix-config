{ lib, pkgs, ... }:
let
  memoryWikiPlugin = import ../lib/build-plugin.nix pkgs {
    name = "memory-wiki";
    rev = "e7a218f26db88426ab3e7376f0e000b6e356f5e7";
    hash = "sha256-zDjiWUVmWUPAyasy74mUuh+d/dpBi1SBh7GZvuTjxcI=";
    requiresHermes = "0.21";
  };
in
{
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 1300 [ memoryWikiPlugin ];
  };
}

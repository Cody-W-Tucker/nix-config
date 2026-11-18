{ lib, pkgs, ... }:
let
  sandboxPlugins = pkgs.fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-official-plugins";
    rev = "e7a218f26db88426ab3e7376f0e000b6e356f5e7";
    hash = "sha256-zDjiWUVmWUPAyasy74mUuh+d/dpBi1SBh7GZvuTjxcI=";
  };
  memoryWikiPlugin = pkgs.runCommand "memory-wiki" { } ''
    cp -R ${sandboxPlugins}/memory-wiki "$out"
    substituteInPlace "$out/plugin.yaml" \
      --replace-fail 'requires_hermes: ">=0.21"' 'requires_hermes: ">=0.0.0"'
  '';
in
{
  services.hermes-agent = {
    extraPlugins = lib.mkOrder 1300 [ memoryWikiPlugin ];
  };
}

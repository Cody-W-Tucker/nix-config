pkgs:
{
  name,
  rev,
  hash,
  requiresHermes,
  owner ? "NousResearch",
  repo ? "hermes-official-plugins",
}:
let
  source = pkgs.fetchFromGitHub {
    inherit
      owner
      repo
      rev
      hash
      ;
  };
in
pkgs.runCommand name { } ''
  cp -R ${source}/${name} "$out"
  substituteInPlace "$out/plugin.yaml" \
    --replace-fail 'requires_hermes: ">=${requiresHermes}"' 'requires_hermes: ">=0.0.0"'
''

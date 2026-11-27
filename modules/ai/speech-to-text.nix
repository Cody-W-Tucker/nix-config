{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.speech-to-text ];

  den.aspects.speech-to-text.provides.to-users.homeManager.imports = [ ./_speech-to-text.nix ];
}

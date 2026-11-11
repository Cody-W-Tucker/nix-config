# Seed only the upstream humanizer; the rest of the bundled catalog stays disabled.
{ inputs, pkgs, ... }:
{
  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "hermes-humanizer";
      root = pkgs.linkFarm "hermes-humanizer-skills" [
        {
          name = "creative/humanizer";
          path = inputs.hermes-agent + "/skills/creative/humanizer";
        }
      ];
      mode = "mutable";
    }
  ];
}

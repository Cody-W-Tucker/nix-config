{ inputs, ... }:
{
  # Every Cognitive Assistant skill; exclusions.nix disables the ones that do not fit.
  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "cognitive-assistant";
      root = inputs.cognitive-assistant.lib.artifacts.skills.categorized;
      mode = "mutable";
    }
  ];
}

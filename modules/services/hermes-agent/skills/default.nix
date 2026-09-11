{
  inputs,
  lib,
  ...
}:

let
  cognitiveAssistantSkills = inputs.cognitive-assistant.lib.artifacts.skills;

  cognitiveAssistantSkillList = lib.concatMapStringsSep "\n" (
    name: "- ${name}"
  ) cognitiveAssistantSkills.names;
in
{
  imports = [
    ./module.nix
    ./seeded-skills.nix
    ./upstream-bundled.nix
    ./business
    ./knowledge
  ];

  config = {
    codyos.hermes-agent.skills = {
      skillPacks = lib.mkAfter [
        {
          name = "cognitive-assistant";
          root = cognitiveAssistantSkills.categorized;
          mode = "mutable";
        }
      ];

      userPatternSkillList = cognitiveAssistantSkillList;
    };
  };
}

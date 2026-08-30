{
  inputs,
  lib,
  ...
}:

let
  enabledUpstreamSkills = [
    "arxiv"
    "github" # Upstream consolidated the former github-{auth,code-review,issues,pr-workflow,repo-management} skills.
    "hermes-agent"
    "hermes-agent-skill-authoring"
    "humanizer"
    "opencode"
    "youtube-content"
    "xurl" # X/Twitter via xurl CLI: post, search, DM, media, v2 API.
    "spike" # Throwaway experiments to validate an idea before build.
    "llm-wiki"
  ];

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
    _module.args.enabledUpstreamSkills = enabledUpstreamSkills;

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

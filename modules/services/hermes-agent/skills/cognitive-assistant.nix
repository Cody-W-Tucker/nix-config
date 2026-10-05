# Filtered Cognitive Assistant pack: all CA skills except the explicit exclusion catalog.
# Filtering uses only Nix artifact paths (readDir on the CA categorized root plus
# the exclusion catalog). No runtime directories are consulted.
{
  inputs,
  lib,
  pkgs,
  defaultExcludedSkillPaths,
  ...
}:
let
  caSkills = inputs.cognitive-assistant.lib.artifacts.skills;
  caCategorized = caSkills.categorized;

  caCategories = builtins.readDir caCategorized;

  categoryDirs = lib.filterAttrs (name: type: type == "directory") caCategories;

  skillsInCategory =
    category:
    let
      entries = builtins.readDir (caCategorized + "/${category}");
      skillDirs = lib.filterAttrs (name: type: type == "directory") entries;
    in
    lib.attrNames skillDirs;

  allCognitiveAssistantRelPaths = lib.sort (a: b: a < b) (
    lib.concatMap (category: map (skill: "${category}/${skill}") (skillsInCategory category)) (
      lib.attrNames categoryDirs
    )
  );

  filteredCognitiveAssistantRelPaths = lib.filter (
    rel: !lib.elem rel defaultExcludedSkillPaths
  ) allCognitiveAssistantRelPaths;

  filteredCognitiveAssistantRoot = pkgs.linkFarm "cognitive-assistant-skills-filtered" (
    map (rel: {
      name = rel;
      path = "${caCategorized}/${rel}";
    }) filteredCognitiveAssistantRelPaths
  );

  excludedLeafNames = map (rel: lib.last (lib.splitString "/" rel)) defaultExcludedSkillPaths;

  filteredSkillNames = lib.filter (
    name: !(lib.elem name defaultExcludedSkillPaths || lib.elem name excludedLeafNames)
  ) caSkills.names;

  filteredSkillList = lib.concatMapStringsSep "\n" (name: "- ${name}") filteredSkillNames;
in
{
  _module.args.allCognitiveAssistantRelPaths = allCognitiveAssistantRelPaths;
  _module.args.filteredCognitiveAssistantRelPaths = filteredCognitiveAssistantRelPaths;
  _module.args.filteredCognitiveAssistantRoot = filteredCognitiveAssistantRoot;

  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "cognitive-assistant";
      root = filteredCognitiveAssistantRoot;
      mode = "mutable";
    }
  ];

  codyos.hermes-agent.skills.userPatternSkillList = filteredSkillList;
}

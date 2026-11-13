# Invariant guard for the explicit default exclusion catalog.
# Every exclusion must be backed by Nix source/evaluated evidence
# (CA categorized, GWS upstream, knowledge entries), never runtime dirs,
# and must be absent from every filtered default pack.
{
  config,
  inputs,
  lib,
  defaultExcludedSkillPaths,
  defaultRetainedGwsSkillNames,
  allCognitiveAssistantRelPaths,
  filteredCognitiveAssistantRelPaths,
  allGwsSkillNames,
  filteredGwsSkillNames,
  allKnowledgeRelPaths,
  filteredKnowledgeRelPaths,
  ...
}:
let
  gwsSourceRels = map (name: "tools/${name}") allGwsSkillNames;
  gwsFilteredRels = map (name: "tools/${name}") filteredGwsSkillNames;
  # Nix-only artifact-source ownership for tools/gws-chat-send:
  # GWS upstream (inputs.googleworkspace-cli/skills/gws-chat-send/SKILL.md),
  # proved via store path existence, not via the 12-skill package catalog
  # (defaultRetainedGwsSkillNames) and never via runtime dirs.
  gwsChatSendSkillFile = inputs.googleworkspace-cli + "/skills/gws-chat-send/SKILL.md";
  gwsChatSendProven = builtins.pathExists gwsChatSendSkillFile;
  extraGwsSourceRels = lib.optionals gwsChatSendProven [ "tools/gws-chat-send" ];
  # Hermes upstream bundled plus optional skills as Nix artifact sources.
  # Every non-CA/non-GWS/non-knowledge exclusion (apple/*, creative/*, ...) is
  # backed by these store paths, never by runtime dirs.
  hermesSkillsRoot = inputs.hermes-agent + "/skills";
  hermesOptionalRoot = inputs.hermes-agent + "/optional-skills";
  hermesCategoryNames =
    root: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir root));
  hermesSkillsInCategory =
    root: category:
    lib.attrNames (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir (root + "/${category}"))
    );
  hermesRelPathsForRoot =
    root:
    lib.concatMap (
      category: map (skill: "${category}/${skill}") (hermesSkillsInCategory root category)
    ) (hermesCategoryNames root);
  allHermesRelPaths = hermesRelPathsForRoot hermesSkillsRoot;
  allHermesOptionalRelPaths = hermesRelPathsForRoot hermesOptionalRoot;
  sourceRels =
    allCognitiveAssistantRelPaths
    ++ gwsSourceRels
    ++ allKnowledgeRelPaths
    ++ extraGwsSourceRels
    ++ allHermesRelPaths
    ++ allHermesOptionalRelPaths;
  defaultRels = filteredCognitiveAssistantRelPaths ++ gwsFilteredRels ++ filteredKnowledgeRelPaths;

  # Retain these paths for cleanup of older seeded skills even though Hermes
  # removed them upstream. Review their status if they appear in a source again.
  retiredSourceRels = [
    "productivity/airtable"
    "productivity/notion"
    "productivity/powerpoint"
    "productivity/xlsx"
  ];
  missingSources = lib.filter (
    rel: !lib.elem rel sourceRels && !lib.elem rel retiredSourceRels
  ) defaultExcludedSkillPaths;
  returnedSources = lib.intersectLists retiredSourceRels sourceRels;

  reseeded = lib.filter (rel: lib.elem rel defaultRels) defaultExcludedSkillPaths;

  packNames = map (pack: pack.name) config.codyos.hermes-agent.skills.skillPacks;
in
{
  config.assertions = [
    {
      assertion = filteredGwsSkillNames == defaultRetainedGwsSkillNames;
      message = "hermes-agent/skills: google-workspace-tools pack must contain exactly the retained GWS catalog.";
    }
    {
      assertion =
        filteredKnowledgeRelPaths == [
          "research/research-state"
        ];
      message = "hermes-agent/skills: knowledge-tools must retain only research-state after exclusions.";
    }
    {
      assertion = lib.elem "crm-tools" packNames;
      message = "hermes-agent/skills: crm-tools pack must stay (CRM stays).";
    }
    {
      assertion = missingSources == [ ];
      message = "hermes-agent/skills: default exclusions missing from Nix sources: ${lib.concatStringsSep ", " missingSources}.";
    }
    {
      assertion =
        returnedSources == [ ] && lib.all (rel: lib.elem rel defaultExcludedSkillPaths) retiredSourceRels;
      message = "hermes-agent/skills: review retired exclusion paths; source returned or cleanup entry was removed: ${lib.concatStringsSep ", " returnedSources}.";
    }
    {
      assertion = gwsChatSendProven;
      message = "hermes-agent/skills: tools/gws-chat-send must exist in GWS upstream Nix source (googleworkspace-cli/skills/gws-chat-send/SKILL.md), not package catalog or runtime dirs.";
    }
    {
      assertion = reseeded == [ ];
      message = "hermes-agent/skills: every default exclusion must be absent from the filtered default packs (CA filtered, GWS retained, knowledge filtered).";
    }
    {
      assertion =
        builtins.length filteredCognitiveAssistantRelPaths == builtins.length allCognitiveAssistantRelPaths
        - builtins.length (lib.intersectLists allCognitiveAssistantRelPaths defaultExcludedSkillPaths);
      message = "hermes-agent/skills: filtered CA pack must retain all non-excluded CA skills.";
    }
  ];
}

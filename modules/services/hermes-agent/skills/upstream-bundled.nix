{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.hermes-agent) hermesHome;

  upstreamBundledSkillsRoot = "${inputs.hermes-agent}/skills";

  directoryNames =
    path: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));

  topLevelUpstreamBundledSkillEntries =
    lib.filter (entry: builtins.pathExists "${entry.source}/SKILL.md")
      (
        map (skill: {
          name = skill;
          relDir = skill;
          source = "${upstreamBundledSkillsRoot}/${skill}";
        }) (directoryNames upstreamBundledSkillsRoot)
      );

  categorizedUpstreamBundledSkillEntries = lib.concatMap (
    category:
    lib.filter (entry: builtins.pathExists "${entry.source}/SKILL.md") (
      map (skill: {
        name = skill;
        relDir = "${category}/${skill}";
        source = "${upstreamBundledSkillsRoot}/${category}/${skill}";
      }) (directoryNames "${upstreamBundledSkillsRoot}/${category}")
    )
  ) (directoryNames upstreamBundledSkillsRoot);

  upstreamBundledSkillEntries =
    topLevelUpstreamBundledSkillEntries ++ categorizedUpstreamBundledSkillEntries;

  bundledSkillPackRoot = pkgs.linkFarm "hermes-agent-enabled-upstream-skills" (
    map (entry: {
      name = entry.relDir;
      path = entry.source;
    }) upstreamBundledSkillEntries
  );
in
{
  config = {
    codyos.hermes-agent.skills.skillPacks = lib.mkBefore [
      {
        name = "upstream-bundled";
        root = bundledSkillPackRoot;
        mode = "managed";
      }
    ];

    # User-scoped Home Manager activation; runs as codyt after upstream's
    # hermes-agent-setup, so HERMES_HOME already exists and no chown is
    # needed. .no-bundled-skills still prevents Hermes from double-copying
    # its own bundle; the managed pack is the source of truth.
    home.activation.hermesAgentEnabledUpstreamSkills = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
      hermes_home="${hermesHome}"
      local_skills_root="$hermes_home/skills"

      mkdir -p "$hermes_home" "$local_skills_root"
      touch "$hermes_home/.no-bundled-skills"
      chmod u+rw "$hermes_home/.no-bundled-skills"
    '';

    # Do not pin services.hermes-agent.settings.skills.disabled. The previous
    # allowlist wrote every non-listed upstream skill into that disable list.
    services.hermes-agent.settings.skills.disabled = lib.mkDefault [ ];
  };
}

{
  config,
  enabledUpstreamSkills,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.hermes-agent) group stateDir user;

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

  upstreamBundledSkillNames = map (entry: entry.name) upstreamBundledSkillEntries;
  unknownEnabledUpstreamSkillNames = lib.filter (
    name: !(lib.elem name upstreamBundledSkillNames)
  ) enabledUpstreamSkills;
  enabledUpstreamSkillEntries = lib.filter (
    entry: lib.elem entry.name enabledUpstreamSkills
  ) upstreamBundledSkillEntries;
  disabledUpstreamSkillNames = lib.filter (
    name: !(lib.elem name enabledUpstreamSkills)
  ) upstreamBundledSkillNames;
  disabledUpstreamSkillEntries = lib.filter (
    entry: !(lib.elem entry.name enabledUpstreamSkills)
  ) upstreamBundledSkillEntries;
  disabledUpstreamSkillRelDirs = map (entry: entry.relDir) disabledUpstreamSkillEntries;
  bundledSkillPackRoot = pkgs.linkFarm "hermes-agent-enabled-upstream-skills" (
    map (entry: {
      name = entry.relDir;
      path = entry.source;
    }) enabledUpstreamSkillEntries
  );
in
{
  config = {
    assertions = [
      {
        assertion = unknownEnabledUpstreamSkillNames == [ ];
        message = ''
          Unknown enabled upstream Hermes bundled skills: ${lib.concatStringsSep ", " unknownEnabledUpstreamSkillNames}
        '';
      }
    ];

    codyos.hermes-agent.skills.skillPacks = lib.mkBefore (
      lib.optional (enabledUpstreamSkills != [ ]) {
        name = "upstream-bundled";
        root = bundledSkillPackRoot;
        mode = "managed";
      }
    );

    system.activationScripts.hermes-agent-enabled-upstream-skills = lib.stringAfter [ "users" ] ''
      hermes_home="${stateDir}/.hermes"
      local_skills_root="$hermes_home/skills"

      mkdir -p "$hermes_home" "$local_skills_root"
      touch "$hermes_home/.no-bundled-skills"
      chown ${user}:${group} "$hermes_home/.no-bundled-skills"
      chmod u+rw,g+rw "$hermes_home/.no-bundled-skills"

      for rel_dir in ${lib.concatMapStringsSep " " lib.escapeShellArg disabledUpstreamSkillRelDirs}; do
        rm -rf "$local_skills_root/$rel_dir"
      done
    '';

    services.hermes-agent.settings.skills.disabled = disabledUpstreamSkillNames;
  };
}

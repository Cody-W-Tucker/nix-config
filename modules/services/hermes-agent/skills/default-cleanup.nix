# Default-home only exclusion cleanup: delete explicit catalog paths after seeding.
# No wildcards, no named-profile paths. Named profiles under profiles/<name> are untouched.
{
  config,
  lib,
  defaultExcludedSkillPaths,
  ...
}:
{
  home.activation.hermesAgentDefaultSkillExclusions =
    lib.hm.dag.entryAfter [ "hermesAgentSeededSkills" ]
      ''
        hermes_home="${config.services.hermes-agent.hermesHome}"
        local_skills_root="$hermes_home/skills"
        mkdir -p "$local_skills_root"
        ${lib.concatMapStringsSep "\n" (
          rel: ''rm -rf "$local_skills_root/${rel}"''
        ) defaultExcludedSkillPaths}
      '';
}

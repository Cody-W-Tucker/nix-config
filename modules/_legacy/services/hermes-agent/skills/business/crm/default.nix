{ pkgs, ... }:

let
  # Upstream SKILL.md from the same pinned release as the crm-cli package
  # (packages/crm-cli), so the skill and the CLI always match.
  crmSkill = "${pkgs.crm-cli.src}/skills/SKILL.md";

  crmSkills = pkgs.linkFarm "hermes-agent-crm-skills" [
    {
      name = "tools/crm-cli/SKILL.md";
      path = crmSkill;
    }
  ];
in
{
  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "crm-tools";
      root = crmSkills;
      mode = "managed";
    }
  ];
}

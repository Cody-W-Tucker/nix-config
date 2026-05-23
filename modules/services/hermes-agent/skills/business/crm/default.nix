{ inputs, pkgs, ... }:

let

  crmSkills = pkgs.linkFarm "hermes-agent-crm-skills" [
    {
      name = "tools/crm-cli/SKILL.md";
      path = "${inputs.crm-cli}/skills/SKILL.md";
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

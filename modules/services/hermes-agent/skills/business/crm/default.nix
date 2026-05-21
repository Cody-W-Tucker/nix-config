{ inputs, pkgs, ... }:

let

  crmSkills = pkgs.linkFarm "hermes-agent-crm-skills" [
    {
      name = "crm-cli/SKILL.md";
      path = "${inputs.crm-cli}/skills/SKILL.md";
    }
  ];
in
{
  codyos.hermes-agent.skills.seedDirs = [ crmSkills ];
}

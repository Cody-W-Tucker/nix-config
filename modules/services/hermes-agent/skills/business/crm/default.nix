{ pkgs, ... }:

let
  # Canonical upstream SKILL.md pinned by content hash.
  # Source: https://github.com/dzhng/crm.cli/blob/main/skills/SKILL.md
  crmSkill = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/dzhng/crm.cli/main/skills/SKILL.md";
    sha256 = "0y44iqgfxzl0r1712pqpm8l39gz8bw74m64dmmvy7ahkmn98gz5a";
  };

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

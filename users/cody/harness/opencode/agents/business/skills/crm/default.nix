{ inputs, ... }:

{
  programs.opencode.skills = {
    crm-cli = builtins.readFile "${inputs.crm-cli}/skills/SKILL.md";
  };
}

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  skills = config.codyos.harness.skills;
  catalog = "${inputs.self}/skills";

  # Same value handling as Home Manager's per-tool skills options: a string is
  # the SKILL.md text; a path is either a skill directory or its SKILL.md.
  mkAgentsSkill =
    name: content:
    if lib.hm.strings.isPathLike content then
      lib.nameValuePair ".agents/skills/${name}" {
        source = pkgs.runCommandLocal "agents-skill-${lib.strings.sanitizeDerivationName name}" { } ''
          source=${lib.escapeShellArg "${content}"}
          if [[ -d "$source" ]]; then
            ln -s "$source" "$out"
          else
            mkdir -p "$out"
            ln -s "$source" "$out/SKILL.md"
          fi
        '';
      }
    else
      lib.nameValuePair ".agents/skills/${name}/SKILL.md" { text = content; };
in
{
  options.codyos.harness.skills = lib.mkOption {
    type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
    default = { };
    description = ''
      Agent Skills shared by every harness. The attribute name is the skill
      directory; the value is SKILL.md text, a SKILL.md path, or a skill
      directory.
    '';
  };

  config = {
    codyos.harness.skills = {
      humanizer = "${catalog}/writing/humanizer";
      make-native = "${catalog}/coding/make-native";
      untangle-codebase = "${catalog}/coding/untangle-codebase";
    };

    # Claude Code reads only ~/.claude/skills. Codex and Pi read only
    # ~/.agents/skills. OpenCode reads both and resolves the identical copies
    # by name, so it needs no skills option of its own.
    programs.claude-code.skills = skills;
    home.file = lib.mapAttrs' mkAgentsSkill skills;
  };
}

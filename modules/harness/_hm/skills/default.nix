{
  config,
  lib,
  pkgs,
  ...
}:

let
  skills = config.codyos.harness.skills;
  humanizerSource = pkgs.fetchFromGitHub {
    owner = "blader";
    repo = "humanizer";
    rev = "8b3a17889fbf12bedae20974a3c9f9de746ed754";
    hash = "sha256-3yO13MKUK/zF36Sq+CACMM401BhtmYz5cZmC5FX4VQw=";
  };
  makeNativeSource = pkgs.fetchFromGitHub {
    owner = "Sloydai";
    repo = "make-native";
    rev = "f7df61dc1f257cde400f0d2533b774a97a34be3e";
    hash = "sha256-ImpoYnEqEBc58avSjEx+ZOYJdm/7ARkoZRtgXZI6f6I=";
  };
  untangleSource = pkgs.fetchFromGitHub {
    owner = "caldoai";
    repo = "skills";
    rev = "d5b68dace378219890d821adb3685538e2c69b04";
    hash = "sha256-VkGhevHArTXRUV87vR5stCIOb6hPqTRJFIOsvwB68Lg=";
  };
  visionSource = pkgs.fetchFromGitHub {
    owner = "kunchenguid";
    repo = "vision";
    rev = "acf4d656188e55ce9633774e4d0c848e9ae49a02";
    hash = "sha256-nHweNF9lUhwbeC58XBSlgGfbVGZvJTfRoNAO/vLdkoQ=";
  };

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
      humanizer = "${humanizerSource}";
      make-native = "${makeNativeSource}/skills/make-native";
      untangle-codebase = "${untangleSource}/skills/untangle-codebase";
      vision = "${visionSource}/skills/vision";
    };

    # Claude Code reads only ~/.claude/skills. Codex and Pi read only
    # ~/.agents/skills. OpenCode reads both and resolves the identical copies
    # by name, so it needs no skills option of its own.
    programs.claude-code.skills = skills;
    home.file = lib.mapAttrs' mkAgentsSkill skills;
  };
}

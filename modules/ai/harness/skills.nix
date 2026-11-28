{
  den.aspects.harness.homeManager =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.codyos.harness) skills;
      fetch =
        owner: repo: rev: hash:
        "${pkgs.fetchFromGitHub {
          inherit
            owner
            repo
            rev
            hash
            ;
        }}";

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
          humanizer =
            fetch "blader" "humanizer" "8b3a17889fbf12bedae20974a3c9f9de746ed754"
              "sha256-3yO13MKUK/zF36Sq+CACMM401BhtmYz5cZmC5FX4VQw=";
          make-native = "${
            fetch "Sloydai" "make-native" "f7df61dc1f257cde400f0d2533b774a97a34be3e"
              "sha256-ImpoYnEqEBc58avSjEx+ZOYJdm/7ARkoZRtgXZI6f6I="
          }/skills/make-native";
          untangle-codebase = "${
            fetch "caldoai" "skills" "d5b68dace378219890d821adb3685538e2c69b04"
              "sha256-VkGhevHArTXRUV87vR5stCIOb6hPqTRJFIOsvwB68Lg="
          }/skills/untangle-codebase";
          vision = "${
            fetch "kunchenguid" "vision" "acf4d656188e55ce9633774e4d0c848e9ae49a02"
              "sha256-nHweNF9lUhwbeC58XBSlgGfbVGZvJTfRoNAO/vLdkoQ="
          }/skills/vision";
        };

        programs.claude-code.skills = skills;
        home.file = lib.mapAttrs' mkAgentsSkill skills;
      };
    };
}

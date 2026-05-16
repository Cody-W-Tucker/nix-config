{
  inputs,
  pkgs,
  ...
}:

let
  layer = inputs.cognitive-assistant.lib.operational;
  payload =
    if layer ? skillAdaptationsFile && builtins.pathExists layer.skillAdaptationsFile then
      builtins.fromJSON (builtins.readFile layer.skillAdaptationsFile)
    else
      {
        version = 1;
        profile = "operational";
        global = {
          prepend = [ ];
        };
        skills = { };
      };

  cleanSections = sections: builtins.filter (section: section != "") sections;

  joinSections =
    sections:
    let
      cleaned = cleanSections sections;
    in
    if cleaned == [ ] then "" else builtins.concatStringsSep "\n\n" cleaned;

  skillEntry =
    skillName:
    payload.skills.${skillName} or {
      prepend = [ ];
      append = [ ];
    };

  globalPrepend = payload.global.prepend or [ ];

  renderAdaptedText =
    skillName: text:
    let
      entry = skillEntry skillName;
      rendered = joinSections (
        globalPrepend ++ (entry.prepend or [ ]) ++ [ text ] ++ (entry.append or [ ])
      );
    in
    if rendered == "" then "" else rendered + "\n";

  payloadFile = pkgs.writeText "skill-adaptations.json" (builtins.toJSON payload);
in
{
  inherit payload;

  applyToText = skillName: text: renderAdaptedText skillName text;

  applyToPath =
    skillName: source:
    let
      sourceString = toString source;
      skillFile =
        if builtins.pathExists "${sourceString}/SKILL.md" then "${sourceString}/SKILL.md" else source;
    in
    renderAdaptedText skillName (builtins.readFile skillFile);

  writeAdaptedSkill =
    {
      skillName,
      source,
      outputName ? "${skillName}-adapted-SKILL.md",
    }:
    pkgs.writeText outputName (
      let
        sourceString = toString source;
        skillFile =
          if builtins.pathExists "${sourceString}/SKILL.md" then "${sourceString}/SKILL.md" else source;
      in
      renderAdaptedText skillName (builtins.readFile skillFile)
    );

  adaptSkillDir =
    {
      sourceDir,
      outputName ? "adapted-skill-dir",
    }:
    pkgs.runCommand outputName { nativeBuildInputs = [ pkgs.python3 ]; } ''
      export SOURCE_DIR="${sourceDir}"
      export PAYLOAD_FILE="${payloadFile}"
      export OUT_DIR="$out"

      ${pkgs.python3}/bin/python <<'PY'
      import json
      import os
      import shutil
      from pathlib import Path

      source_dir = Path(os.environ["SOURCE_DIR"])
      payload = json.loads(Path(os.environ["PAYLOAD_FILE"]).read_text(encoding="utf-8"))
      out_dir = Path(os.environ["OUT_DIR"])

      shutil.copytree(source_dir, out_dir, dirs_exist_ok=True)

      for path in [out_dir, *out_dir.rglob("*")]:
          if path.is_symlink():
              continue
          path.chmod(path.stat().st_mode | 0o200)

      global_prepend = payload.get("global", {}).get("prepend", [])
      skills = payload.get("skills", {})

      def render(skill_name: str, body: str) -> str:
          entry = skills.get(skill_name, {})
          sections = [*global_prepend, *(entry.get("prepend", [])), body, *(entry.get("append", []))]
          cleaned = [section for section in sections if section]
          if not cleaned:
              return ""
          return "\n\n".join(cleaned).rstrip() + "\n"

      for skill_md in out_dir.rglob("SKILL.md"):
          skill_name = skill_md.parent.name
          body = skill_md.read_text(encoding="utf-8")
          skill_md.unlink()
          skill_md.write_text(render(skill_name, body), encoding="utf-8")
      PY
    '';
}

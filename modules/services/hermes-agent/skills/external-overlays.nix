{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.hermes-agent) group stateDir user;
  externalSkillDirs = config.services.hermes-agent.settings.skills.external_dirs or [ ];
  externalSkillDirsShell = lib.concatMapStringsSep " " lib.escapeShellArg externalSkillDirs;
in
{
  config.system.activationScripts.hermes-agent-external-skill-overlays =
    lib.stringAfter [ "users" ]
      ''
            hermes_home="${stateDir}/.hermes"
            local_skills_root="$hermes_home/skills/external-overlays"

            mkdir -p "$local_skills_root"

            for source_dir in ${externalSkillDirsShell}; do
              [ -d "$source_dir" ] || continue

              ${pkgs.findutils}/bin/find "$source_dir" -type f -name SKILL.md | while IFS= read -r skill_md; do
                skill_dir="$(dirname "$skill_md")"
                rel_dir="''${skill_dir#"$source_dir"/}"
                dest_dir="$local_skills_root/$rel_dir"
                dest_skill="$dest_dir/SKILL.md"
                amendments_file="$dest_dir/references/hermes-local-amendments.md"

                mkdir -p "$dest_dir/references"

                if [ ! -f "$amendments_file" ]; then
                  cat > "$amendments_file" <<EOF
        # Local Amendments

        Record Hermes-specific adjustments for this external skill here instead of
        editing the upstream skill snapshot.

        - Add durable clarifications, caveats, and operator preferences here.
        - Prefer appending new notes over rewriting the generated SKILL.md wrapper.
        EOF
                fi

                python_script=$(mktemp)
                cat > "$python_script" <<'PY'
        from pathlib import Path
        import sys

        source_path = Path(sys.argv[1])
        dest_path = Path(sys.argv[2])
        amendments_rel = sys.argv[3]

        raw = source_path.read_text(encoding="utf-8")
        frontmatter = ""
        body = raw

        if raw.startswith("---\n"):
            end = raw.find("\n---\n", 4)
            if end != -1:
                frontmatter = raw[: end + 5]
                body = raw[end + 5 :]

        wrapper = f"""{frontmatter}# External Skill Overlay

        This writable local overlay shadows the read-only external skill at `{source_path}`.

        When Hermes needs to preserve changes for this skill, store them in
        `{amendments_rel}` instead of editing the upstream skill snapshot.

        Read `{amendments_rel}` before using this skill. If the local amendments conflict
        with the upstream snapshot below, follow the local amendments.

        ## Upstream Skill Snapshot

        {body}"""

        dest_path.write_text(wrapper, encoding="utf-8")
        PY
                ${pkgs.python3}/bin/python "$python_script" "$skill_md" "$dest_skill" "references/hermes-local-amendments.md"
                rm -f "$python_script"
              done
            done

            chown -R ${user}:${group} "$local_skills_root"
            chmod -R u+rwX,g+rwX "$local_skills_root"
      '';
}

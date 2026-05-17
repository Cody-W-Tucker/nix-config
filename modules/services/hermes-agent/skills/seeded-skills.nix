{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.hermes-agent) group stateDir user;
  seedDirs = config.codyos.hermes-agent.skills.seedDirs;
  seedDirsShell = lib.concatMapStringsSep " " lib.escapeShellArg seedDirs;
in
{
  config.system.activationScripts.hermes-agent-seeded-skills = lib.stringAfter [ "users" ] ''
    hermes_home="${stateDir}/.hermes"
    local_skills_root="$hermes_home/skills"

    mkdir -p "$local_skills_root"

    for source_dir in ${seedDirsShell}; do
      [ -d "$source_dir" ] || continue

      ${pkgs.findutils}/bin/find -L "$source_dir" -name SKILL.md | while IFS= read -r skill_md; do
        skill_dir="$(dirname "$skill_md")"
        rel_dir="''${skill_dir#"$source_dir"/}"
        dest_dir="$local_skills_root/$rel_dir"

        if [ -L "$dest_dir" ] || [ -L "$dest_dir/SKILL.md" ]; then
          rm -rf "$dest_dir"
        fi

        if [ -e "$dest_dir/SKILL.md" ]; then
          continue
        fi

        mkdir -p "$(dirname "$dest_dir")"
        cp -rL "$skill_dir" "$dest_dir"
        chown -R ${user}:${group} "$dest_dir"
        chmod -R u+rwX,g+rwX "$dest_dir"
      done
    done
  '';
}

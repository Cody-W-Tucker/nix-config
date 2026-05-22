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
        needs_reset=0

        # Seeded skills must live under HERMES_HOME as normal files so Hermes
        # can edit them. Older runs may have left symlinks back into /nix/store.
        if [ -L "$dest_dir" ] || [ -L "$dest_dir/SKILL.md" ]; then
          needs_reset=1
        elif [ -d "$dest_dir" ] && ${pkgs.findutils}/bin/find "$dest_dir" -type l -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
          needs_reset=1
        fi

        if [ "$needs_reset" -eq 1 ]; then
          rm -rf "$dest_dir"
        fi

        if [ ! -e "$dest_dir/SKILL.md" ]; then
          mkdir -p "$(dirname "$dest_dir")"
          cp -rL "$skill_dir" "$dest_dir"
        fi

        chown -R ${user}:${group} "$dest_dir"
        chmod -R u+rwX,g+rwX "$dest_dir"
      done
    done
  '';
}

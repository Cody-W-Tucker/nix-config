{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.hermes-agent) group stateDir user;
  cfg = config.codyos.hermes-agent.skills;

  legacySeedPacks = map (dir: {
    name = "legacy-seed-dir";
    root = dir;
    mode = "mutable";
    staleDirs = [ ];
  }) cfg.seedDirs;

  skillPacks = cfg.skillPacks ++ legacySeedPacks;

  packCommands = lib.concatMapStringsSep "\n" (pack: ''
    seed_skill_pack ${lib.escapeShellArg pack.root} ${lib.escapeShellArg pack.mode}
  '') skillPacks;

  staleDirs = cfg.staleDirs ++ lib.flatten (map (pack: pack.staleDirs) skillPacks);
  staleDirsShell = lib.concatMapStringsSep " " lib.escapeShellArg staleDirs;
in
{
  config.system.activationScripts.hermes-agent-seeded-skills = lib.stringAfter [ "users" ] ''
    hermes_home="${stateDir}/.hermes"
    local_skills_root="$hermes_home/skills"

    mkdir -p "$local_skills_root"

    # Remove explicit migration/stale paths before seeding. This is how we move
    # flat generated skills into Hermes-style category/skill directories without
    # leaving duplicate skill names behind.
    for rel_dir in ${staleDirsShell}; do
      [ -n "$rel_dir" ] || continue
      case "$rel_dir" in
        /*|*..*)
          echo "refusing unsafe Hermes stale skill path: $rel_dir" >&2
          continue
          ;;
      esac
      rm -rf "$local_skills_root/$rel_dir"
    done

    # Hermes resolves local skills from category/skill directories. If a partial
    # directory exists without SKILL.md, it can shadow the real packaged skill.
    for category_dir in "$local_skills_root"/*; do
      [ -d "$category_dir" ] || continue

      for skill_dir in "$category_dir"/*; do
        [ -d "$skill_dir" ] || continue

        if [ ! -e "$skill_dir/SKILL.md" ]; then
          rm -rf "$skill_dir"
        fi
      done
    done

    seed_skill_pack() {
      source_dir="$1"
      mode="$2"

      [ -d "$source_dir" ] || return 0

      ${pkgs.findutils}/bin/find -L "$source_dir" -name SKILL.md | while IFS= read -r skill_md; do
        skill_dir="$(dirname "$skill_md")"
        rel_dir="''${skill_dir#"$source_dir"/}"
        dest_dir="$local_skills_root/$rel_dir"
        needs_reset=0

        # Seeded skills must live under HERMES_HOME as normal files so Hermes
        # can edit them. Older runs may have left symlinks back into /nix/store.
        if [ "$mode" = "managed" ]; then
          needs_reset=1
        elif [ -L "$dest_dir" ] || [ -L "$dest_dir/SKILL.md" ]; then
          needs_reset=1
        elif [ -d "$dest_dir" ] && [ ! -e "$dest_dir/SKILL.md" ]; then
          # Partial local skill dirs shadow the source skill but cannot load.
          # Remove them so the source SKILL.md can be copied below.
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
    }

    ${packCommands}
  '';
}

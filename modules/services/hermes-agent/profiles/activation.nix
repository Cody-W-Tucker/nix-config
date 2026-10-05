# Per-profile activation: Nix owns config.yaml/SOUL.md/profile.yaml; memories and skill copies seed only when missing.
{
  config,
  inputs,
  lib,
  pkgs,
  profileDefinitions,
  profileConfigs,
  profileSouls,
  profileMeta,
  skillPacksByName,
  ...
}:
let
  inherit (config.services.hermes-agent) hermesHome;
  caArtifacts = inputs.cognitive-assistant.lib.artifacts;
  caSkillsRoot = caArtifacts.skills.categorized;
  caSkillsRootEscaped = lib.escapeShellArg caSkillsRoot;

  # Parked by construction: placeholder .env only (never tokens), no messaging sections.
  placeholderEnv = ''
    # Per-profile secrets for this Hermes profile.
    # Parked: no messaging adapters or credentials are provisioned here.
    # Behavioral settings belong in config.yaml, not here.
  '';

  mkProfileScript = name: profile: ''
      profile_dir="$hermes_home/profiles/${name}"
      mkdir -p "$profile_dir/memories" "$profile_dir/sessions" "$profile_dir/skills" "$profile_dir/skins" "$profile_dir/logs" "$profile_dir/plans" "$profile_dir/workspace" "$profile_dir/cron" "$profile_dir/home"

      # Parked credentials file: placeholder only when absent, never overwrite.
      if [ ! -e "$profile_dir/.env" ]; then
        printf '%s' ${lib.escapeShellArg placeholderEnv} > "$profile_dir/.env"
        chmod 0600 "$profile_dir/.env"
      fi

      # Nix-owned files: overwrite every activation.
      cp -f ${profileConfigs.${name}} "$profile_dir/config.yaml"
      chmod 0600 "$profile_dir/config.yaml"
      cp -f ${profileSouls.${name}} "$profile_dir/SOUL.md"
      chmod 0600 "$profile_dir/SOUL.md"
      cp -f ${profileMeta.${name}} "$profile_dir/profile.yaml"
      chmod 0600 "$profile_dir/profile.yaml"

      # Mutable memory: seed only when missing.
      if [ ! -e "$profile_dir/memories/MEMORY.md" ]; then
        printf '# Memory\n\nPer-profile working memory. Agent-owned.\n' > "$profile_dir/memories/MEMORY.md"
        chmod 0600 "$profile_dir/memories/MEMORY.md"
      fi
      if [ ! -e "$profile_dir/memories/USER.md" ]; then
        printf '# User\n\nPer-profile user notes. Agent-owned.\n' > "$profile_dir/memories/USER.md"
        chmod 0600 "$profile_dir/memories/USER.md"
      fi

      # Nix-owned seeded curated skills, mutable-preserving: copy a skill only
      # when its destination has no SKILL.md.
      # Strict: a missing declared skill fails activation deterministically.
      for skill_name in ${lib.escapeShellArgs profile.curatedSkills}; do
        src_dir=$(${pkgs.findutils}/bin/find -L ${caSkillsRootEscaped} -maxdepth 3 -type d -name "$skill_name" -print -quit)
        if [ -z "$src_dir" ]; then
          echo "hermes-agent/profiles:${name}: missing curated skill \"$skill_name\" under CA skills root" >&2
          exit 1
        fi
        # Source layout is <root>/<category>/<skill>; keep that nesting so
        # Hermes resolves local skills from category/skill directories.
        category=$(basename "$(dirname "$src_dir")")
        dest_dir="$profile_dir/skills/$category/$skill_name"
        if [ ! -e "$dest_dir/SKILL.md" ]; then
          rm -rf "$dest_dir"
          mkdir -p "$(dirname "$dest_dir")"
          cp -rL "$src_dir" "$dest_dir"
          chmod -R u+rwX "$dest_dir"
        fi
      done
    ${lib.concatMapStringsSep "\n" (
      packName:
      let
        pack =
          skillPacksByName.${packName}
            or (throw "hermes-agent/profiles:${name}: business skill pack '${packName}' not found in codyos.hermes-agent.skills.skillPacks (expected from skills/business/crm and google-workspace)");
      in
      ''
        # Declarative business pack '${packName}' from Nix store, never ~/.local/share.
        business_src=${lib.escapeShellArg pack.root}
        if [ ! -d "$business_src" ]; then
          echo "hermes-agent/profiles:${name}: missing declarative business pack '${packName}' at $business_src" >&2
          exit 1
        fi
        if [ ! -d "$business_src/tools" ]; then
          echo "hermes-agent/profiles:${name}: business pack '${packName}' has no tools/ dir at $business_src/tools" >&2
          exit 1
        fi
        business_found=0
        for business_dir in "$business_src"/tools/*; do
          [ -d "$business_dir" ] || continue
          [ -e "$business_dir/SKILL.md" ] || [ -n "$(ls -A "$business_dir" 2>/dev/null)" ] || continue
          business_base=$(basename "$business_dir")
          business_dest="$profile_dir/skills/tools/$business_base"
          business_found=1
          if [ ! -e "$business_dest/SKILL.md" ]; then
            rm -rf "$business_dest"
            mkdir -p "$(dirname "$business_dest")"
            cp -rL "$business_dir" "$business_dest"
            chmod -R u+rwX "$business_dest"
          fi
        done
        if [ "$business_found" -eq 0 ]; then
          echo "hermes-agent/profiles:${name}: business pack '${packName}' seeded no skills from $business_src/tools" >&2
          exit 1
        fi
      ''
    ) profile.businessPacks}
  '';

  profileScripts = lib.concatStringsSep "\n" (lib.mapAttrsToList mkProfileScript profileDefinitions);
in
{
  # Ownership: Home Manager user activation (login user owns $hermes_home), so no chown.
  config.home.activation.hermesAgentProfiles = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
    hermes_home="${hermesHome}"
    mkdir -p "$hermes_home/profiles"

    ${profileScripts}
  '';
}

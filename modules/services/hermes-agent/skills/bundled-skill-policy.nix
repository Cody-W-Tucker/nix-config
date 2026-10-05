{
  config,
  lib,
  ...
}:
{
  config = {
    # Upstream bundled skill catalog is deliberately opt-out via marker.
    # User-scoped Home Manager activation; runs as user after seeded skills,
    # so no chown is needed. Marker is retained, never deleted.
    home.activation.hermesAgentBundledSkillPolicy =
      lib.hm.dag.entryAfter [ "hermesAgentSeededSkills" ]
        ''
          hermes_home="${config.services.hermes-agent.hermesHome}"
          mkdir -p "$hermes_home"
          if [ ! -e "$hermes_home/.no-bundled-skills" ]; then
            : > "$hermes_home/.no-bundled-skills"
          fi
          chmod 0600 "$hermes_home/.no-bundled-skills"
        '';

    # Do not pin services.hermes-agent.settings.skills.disabled. The previous
    # allowlist wrote every non-listed upstream skill into that disable list.
    services.hermes-agent.settings.skills.disabled = lib.mkDefault [ ];
  };
}

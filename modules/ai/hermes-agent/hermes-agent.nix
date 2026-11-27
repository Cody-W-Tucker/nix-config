{
  den,
  inputs,
  ...
}:
{
  den.aspects.nas.includes = [ den.aspects.hermes-agent ];

  den.aspects.hermes-agent = {
    includes = [ den.aspects.google-workspace.hermes ];
    provides.to-users.homeManager.imports = [ ./_bridge ];

    nixos =
      { config, lib, ... }:
      let
        site = config.codyos.site;
        hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
      in
      {
        imports = [
          inputs.workflow.nixosModules.default
          ./_nixos
        ];

        users.users.${site.user.name}.extraGroups = [ config.services.hermes-agent.group ];

        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
          (import ./_endpoint.nix).port
          9119
        ];

        services.restic.backups.nas-files.exclude = map (suffix: "${hermesHome}/${suffix}") [
          "audio_cache"
          "cache"
          "**/*.db"
          "**/*.db-wal"
          "**/*.db-shm"
          "**/*.sqlite"
          "**/*.sqlite-wal"
          "**/*.sqlite-shm"
        ];

        nas.backups.sqlite = [
          {
            name = "hermes";
            source = "${config.services.hermes-agent.stateDir}/crm/crm.db";
            filename = "crm/crm.db";
          }
        ]
        ++
          map
            (rel: {
              name = "hermes";
              source = "${hermesHome}/${rel}";
              filename = rel;
            })
            (
              [
                "state.db"
                "kanban.db"
                "shared-state.db"
                "memory_store.db"
                "projects.db"
                "response_store.db"
                "runs_idempotency.db"
                "verification_evidence.db"
                "cron/executions.db"
                "cron/notepad.db"
              ]
              ++
                lib.concatMap
                  (profile: [
                    "profiles/${profile}/state.db"
                    "profiles/${profile}/memory_store.db"
                    "profiles/${profile}/projects.db"
                    "profiles/${profile}/cron/executions.db"
                  ])
                  [
                    "builder"
                    "research"
                    "tmv-sales"
                  ]
            );
        nas.backups.dataDirectories = [
          hermesHome
          "${config.services.hermes-agent.stateDir}/cognitive-assistant"
          config.services.hermes-agent.workingDirectory
        ];
      };
  };
}

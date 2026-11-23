{ den, inputs, ... }:
{
  # Include only on the NAS: this aspect needs nas.backups.*.
  den.aspects.hermes-agent = {
    includes = [
      den.aspects.google-workspace.hermes
      den.aspects.research-state.hermes
    ];
    provides.to-users.homeManager.imports = [ ./_hm ];
    # Hermes runs as user services; linger keeps them up after logout.
    provides.to-users.user.linger = true;

    nixos =
      { config, lib, ... }:
      let
        site = config.codyos.site;
      in
      {
        imports = [ inputs.workflow.nixosModules.default ];

        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
          (import ./_endpoint.nix).port
          9119
        ];

        # Live databases and caches are not consistent Restic inputs.
        services.restic.backups.nas-files.exclude =
          map (suffix: "${site.user.home}/.local/share/hermes/${suffix}")
            [
              "audio_cache"
              "cache"
              "**/*.db"
              "**/*.db-wal"
              "**/*.db-shm"
              "**/*.sqlite"
              "**/*.sqlite-wal"
              "**/*.sqlite-shm"
            ];

        # Exports mirror the layout under hermesHome, so a restore copies each
        # file back to the same relative path. A listed database that no longer
        # exists fails the backup run; remove it here when Hermes drops it.
        nas.backups.sqlite =
          map
            (rel: {
              name = "hermes";
              source = "${site.user.home}/.local/share/hermes/${rel}";
              filename = rel;
            })
            (
              [
                "state.db"
                "crm/crm.db"
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
          "${site.user.home}/.local/share/hermes"
        ];
      };
  };
}

{ inputs, ... }:
{
  # Hermes agent: one aspect, two halves. Include it on a host to get both.
  #  - homeManager: the Hermes Home Manager module tree (_hm), delivered to every user of
  #    the including host through provides.to-users (Den delivers an included aspect's
  #    provides.to-users to the host's users; den test deadbugs/issue-692).
  #  - nixos: backup wiring. The state and CRM SQLite files are exported by Restic's
  #    pre-backup step; remaining state is a direct Restic input (live *.db* files stay
  #    excluded below). nas.backups.* exists only
  #    on the nas host (modules/backups/), so include this on nas only.
  den.aspects.hermes-agent = {
    provides.to-users.homeManager.imports = [ ./_hm ];
    # Hermes runs as user services; linger keeps them up after logout.
    provides.to-users.user.linger = true;

    nixos =
      { config, ... }:
      let
        site = config.codyos.site;
      in
      {
        # Installs the workflow CLI (inputs.workflow.packages.*.workflowCli) system-wide;
        # the Home Manager half wires the same package into Hermes.
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

        nas.backups.sqlite = [
          {
            name = "hermes";
            source = "${site.user.home}/.local/share/hermes/state.db";
            filename = "state.db";
          }
          {
            name = "hermes";
            source = "${site.user.home}/.local/share/hermes/crm/crm.db";
            filename = "crm.db";
          }
        ];
        nas.backups.dataDirectories = [
          "${site.user.home}/.local/share/hermes"
        ];
      };
  };
}

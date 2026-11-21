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
      { config, ... }:
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

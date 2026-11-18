{
  # Hermes agent: one aspect, two halves. Include it on a host to get both.
  #  - homeManager: the Hermes Home Manager module tree (_hm), delivered to every user of
  #    the including host through provides.to-users (Den delivers an included aspect's
  #    provides.to-users to the host's users; den test deadbugs/issue-692).
  #  - nixos: backup wiring. The state and CRM SQLite files are exported by Restic's
  #    pre-backup step; remaining state is a direct Restic input (live *.db* files stay
  #    excluded centrally in modules/server/backups.nix). nas.backups.* exists only
  #    on hosts with the nas role, so include this on nas only.
  den.aspects.hermes-agent = {
    provides.to-users.homeManager.imports = [ ./_hm ];

    nixos =
      { config, ... }:
      let
        site = config.codyos.site;
      in
      {
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

{
  # Hermes runs as a Home Manager user service; the HM module tree
  # (modules/services/hermes-agent) is imported in the nas user's import list in
  # den/hosts/nas.nix, because the position of that import in the single user
  # definition affects home.packages order (and so the derivation).
  # This aspect carries the NixOS-level half: the state and CRM SQLite files are
  # exported by Restic's pre-backup step; remaining state is a direct Restic
  # input (live *.db* files stay excluded centrally in modules/nas/backups.nix).
  # nas.backups.* exists only on hosts with modules/nas, so include this on nas only.
  den.aspects.hermes-agent.nixos =
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
}

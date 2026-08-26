{
  pkgs,
  ...
}:

{
  # ── ZFS datasets ──────────────────────────────────────────────
  # Create idempotently and ensure readiness before nfs-server starts.

  systemd.services."zfs-create-backup-projects" = {
    description = "Ensure ZFS dataset backup/projects exists and is mounted";
    wantedBy = [ "multi-user.target" ];
    before = [
      "nfs-server.service"
      "shutdown.target"
    ];
    after = [ "zfs-import-backup.service" ];
    requires = [ "zfs-import-backup.service" ];
    conflicts = [ "shutdown.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! ${pkgs.zfs}/bin/zfs list -H -o name backup/projects &>/dev/null; then
        ${pkgs.zfs}/bin/zfs create -o mountpoint=/mnt/projects backup/projects
      else
        ${pkgs.zfs}/bin/zfs set mountpoint=/mnt/projects backup/projects
      fi
      ${pkgs.zfs}/bin/zfs mount backup/projects 2>/dev/null || true
      ${pkgs.coreutils}/bin/chown 1000:100 /mnt/projects
    '';
  };

  systemd.services."zfs-create-backup-knowledge" = {
    description = "Ensure ZFS dataset backup/knowledge exists and is mounted";
    wantedBy = [ "multi-user.target" ];
    before = [
      "nfs-server.service"
      "shutdown.target"
    ];
    after = [ "zfs-import-backup.service" ];
    requires = [ "zfs-import-backup.service" ];
    conflicts = [ "shutdown.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! ${pkgs.zfs}/bin/zfs list -H -o name backup/knowledge &>/dev/null; then
        ${pkgs.zfs}/bin/zfs create -o mountpoint=/mnt/knowledge backup/knowledge
      else
        ${pkgs.zfs}/bin/zfs set mountpoint=/mnt/knowledge backup/knowledge
      fi
      ${pkgs.zfs}/bin/zfs mount backup/knowledge 2>/dev/null || true
      ${pkgs.coreutils}/bin/chown 1000:100 /mnt/knowledge
    '';
  };

  # ── NFS server ────────────────────────────────────────────────
  # Export only to Beast on the LAN.  Tailscale is NOT used for
  # these shares.

  services.nfs.server = {
    enable = true;
    exports = ''
      # /mnt/projects sees high-write dev workloads (pnpm installs, node_modules churn). the trade-off is that a NAS crash or power loss can lose recent acknowledged writes.
      /mnt/projects  192.168.1.0/24(rw,async,no_subtree_check)
      /mnt/knowledge 192.168.1.0/24(rw,sync,no_subtree_check)
    '';
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
}

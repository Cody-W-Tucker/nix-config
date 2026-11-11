{
  config,
  ...
}:

{
  # ── NFS server ────────────────────────────────────────────────
  # Export only to Beast on the LAN.  Tailscale is NOT used for
  # these shares.

  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/projects ${config.codyos.site.lan.subnet}(rw,sync,no_subtree_check)
      /mnt/knowledge ${config.codyos.site.lan.subnet}(rw,sync,no_subtree_check)
    '';
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
}

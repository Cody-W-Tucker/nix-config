{
  # Calibre content server for Readarr metadata lookups
  services.calibre-server = {
    enable = true;
    group = "media";
    libraries = [ "/mnt/media/Books" ];
    port = 7007;
    openFirewall = true;
    extraFlags = [ "--trusted-ips=127.0.0.1,::1" ];
  };
}

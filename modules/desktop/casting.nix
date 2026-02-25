{ pkgs, ... }:

{
  # Avahi for network discovery (required by gnome-network-displays)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # Chromecast and casting support
  environment.systemPackages = with pkgs; [
    (pkgs.symlinkJoin {
      name = "gnome-network-displays";
      paths = [ pkgs.gnome-network-displays ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/gnome-network-displays \
          --set GDK_BACKEND x11 \
          --prefix GIO_EXTRA_MODULES : ${pkgs.glib-networking}/lib/gio/modules \
          --prefix LD_LIBRARY_PATH : ${pkgs.gnutls}/lib
      '';
    })
  ];

  # Simple firewall - just the essential ports
  networking.firewall = {
    allowedTCPPorts = [
      8008 # Chromecast HTTP
      8009 # Chromecast TLS
    ];
    allowedUDPPorts = [
      5353 # mDNS
      1900 # SSDP
    ];
  };
}

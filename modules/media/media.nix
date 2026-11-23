{
  den,
  inputs,
  ...
}:
{
  den.aspects.nas.includes = [ den.aspects.media ];

  den.aspects.media = {
    includes = [
      den.aspects.arr-stack
      den.aspects.audiobookshelf
      den.aspects.calibre
      den.aspects.jellyfin
      den.aspects.navidrome
      den.aspects.seerr
      den.aspects.shelfmark
      den.aspects.transmission
    ];

    nixos = {
      # vpn-confinement declares vpnNamespaces and systemd.services.<name>.vpnConfinement;
      # transmission.nix defines the wg namespace and arr-stack.nix confines its services
      # in it, so the module is imported once here, by the aspect that includes both.
      imports = [ inputs.vpn-confinement.nixosModules.default ];

      # Containers need the existing NAS media GID at evaluation time.
      # An auto-assigned GID is only available at runtime.
      users.groups.media.gid = 983;

      # Keep the parent root-owned to avoid unsafe ownership transitions.
      systemd.tmpfiles.rules = [
        "d /mnt/media 0755 root root - -"
        "d /mnt/media/AudioBookShelf 2775 root media - -"
        "d /mnt/media/Books 2775 root media - -"
        "d /mnt/media/Channels 2775 root media - -"
        "d /mnt/media/Downloads 2775 root media - -"
        "d /mnt/media/Downloads/incomplete 2775 root media - -"
        # Shelfmark pins Transmission ebook torrents here. Must exist before
        # Transmission moves a completed torrent into it.
        "d /mnt/media/Downloads/books 2775 root media - -"
        "d /mnt/media/Movies 2775 root media - -"
        "d /mnt/media/Music 2775 root media - -"
        "d /mnt/media/TV\\x20Shows 2775 root media - -"
      ];
    };
  };
}

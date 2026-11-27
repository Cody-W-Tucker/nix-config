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
      imports = [ inputs.vpn-confinement.nixosModules.default ];

      users.groups.media.gid = 983;

      systemd.tmpfiles.rules = [
        "d /mnt/media 0755 root root - -"
        "d /mnt/media/AudioBookShelf 2775 root media - -"
        "d /mnt/media/Books 2775 root media - -"
        "d /mnt/media/Channels 2775 root media - -"
        "d /mnt/media/Downloads 2775 root media - -"
        "d /mnt/media/Downloads/incomplete 2775 root media - -"
        "d /mnt/media/Downloads/books 2775 root media - -"
        "d /mnt/media/Movies 2775 root media - -"
        "d /mnt/media/Music 2775 root media - -"
        "d /mnt/media/TV\\x20Shows 2775 root media - -"
      ];
    };
  };
}

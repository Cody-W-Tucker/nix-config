{ den, inputs, ... }:
{
  # Media stack: one aspect per service in this directory, plus the shared base
  # directory tree and the media group they all use.
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

      # Pin the media group GID so container PUID/PGID environment strings can
      # reference it at eval time: auto-assigned GIDs are not visible to the
      # module system (config.users.groups.<name>.gid stays null), which is
      # what previously forced hardcoded literals like PGID = "983". Scoped
      # to the NAS media stack rather than the base accounts aspect because
      # that is shared with hosts whose group-id space cannot be
      # verified here; a static GID forced on all of them could collide. On
      # this host 983 matches the GID already assigned at runtime (verified
      # via getent), so activation is a no-op.
      users.groups.media.gid = 983;

      # Base media directory tree. Shared by Transmission (downloads),
      # the *arr stack (library consumption), and related media services.
      # Base directory is owned by root to avoid unsafe path transitions
      # when subdirectories are owned by different users.
      systemd.tmpfiles.rules = [
        "d /mnt/media 0755 root root - -"
        # Flat media category directories with setgid for group inheritance
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

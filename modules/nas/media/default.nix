{ lib, config, ... }:

{
  imports = [
    ./arr-stack.nix
    ./audiobookshelf.nix
    ./calibre.nix
    ./jellyfin.nix
    ./navidrome.nix
    ./seerr.nix
    ./shelfmark.nix
    ./transmission.nix
  ];

  # Pin the media group GID so container PUID/PGID environment strings can
  # reference it at eval time: auto-assigned GIDs are not visible to the
  # module system (config.users.groups.<name>.gid stays null), which is
  # what previously forced hardcoded literals like PGID = "983". Scoped
  # to the NAS media stack rather than modules/system/users.nix because
  # that users module is shared with hosts whose group-id space cannot be
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
    "d /mnt/media/Movies 2775 root media - -"
    "d /mnt/media/Music 2775 root media - -"
    "d /mnt/media/TV\\x20Shows 2775 root media - -"
  ];
}

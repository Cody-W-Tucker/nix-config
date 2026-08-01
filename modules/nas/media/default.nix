{ lib, config, ... }:

{
  imports = [
    ./arr-stack.nix
    ./calibre.nix
    ./jellyfin.nix
    ./navidrome.nix
    ./seerr.nix
    ./transmission.nix
  ];

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

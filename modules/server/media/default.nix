{ lib, ... }:

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

  # Reusable nginx reverse-proxy vhost builder.
  # Covers the common pattern across media services:
  #   forceSSL + useACMEHost "homehub.tv" + kTLS + single-location proxyPass
  #   + recommendedProxySettings (on by default, since all reverse-proxied
  #   media services benefit from standard proxy headers).
  # `port` accepts an int (e.g. a service's configured default port) or a
  # string; the helper applies `toString` internally so callers can pass
  # `config.services.<name>.settings.port` directly without wrapping.
  # Returns a singleton attrset { "<host>" = { ... }; } suitable for merging
  # into services.nginx.virtualHosts via `//`.
  _module.args.mkMediaVhost =
    {
      host,
      port,
      proxyHost ? "127.0.0.1",
      extraConfig ? "",
      recommendedProxySettings ? true,
    }:
    {
      ${host} = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        kTLS = true;
        inherit recommendedProxySettings;
        locations."/" = {
          proxyPass = "http://${proxyHost}:${toString port}";
          proxyWebsockets = true;
        }
        // lib.optionalAttrs (extraConfig != "") { inherit extraConfig; };
      };
    };
}

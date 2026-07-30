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

  # Reusable nginx reverse-proxy vhost builder.
  # Covers the common pattern across media services:
  #   forceSSL + useACMEHost "homehub.tv" + kTLS + single-location proxyPass
  #   + recommendedProxySettings is set globally in modules/server/default.nix
  #
  # Accepts either:
  #   - `service`: a service name (e.g. "sonarr") — derives host as
  #     "${service}.homehub.tv" and port from config.services.${service}.settings.server.port
  #   - `host` + `port`: explicit values for services without a standard
  #     settings.server.port option or non-standard hostnames
  #
  # `port` accepts an int or string; the helper applies `toString` internally.
  # Returns a singleton attrset { "<host>" = { ... }; } suitable for merging
  # into services.nginx.virtualHosts via `//`.
  _module.args.mkMediaVhost =
    {
      host ? null,
      port ? null,
      service ? null,
      proxyHost ? "127.0.0.1",
      extraConfig ? "",
    }:
    let
      # Derive host and port from service name if provided
      resolvedHost = if service != null then "${service}.homehub.tv" else host;
      resolvedPort = if service != null then config.services.${service}.settings.server.port else port;
    in
    assert lib.assertMsg (
      resolvedHost != null
    ) "mkMediaVhost: either `host` or `service` must be provided";
    assert lib.assertMsg (
      resolvedPort != null
    ) "mkMediaVhost: either `port` or `service` must be provided";
    {
      ${resolvedHost} = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        kTLS = true;
        locations."/" = {
          proxyPass = "http://${proxyHost}:${toString resolvedPort}";
          proxyWebsockets = true;
        }
        // lib.optionalAttrs (extraConfig != "") { inherit extraConfig; };
      };
    };
}

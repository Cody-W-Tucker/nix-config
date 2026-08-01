{ lib, config, ... }:

{
  # System-wide nginx vhost builder.
  # Covers the common reverse-proxy pattern used across this flake:
  #   forceSSL + ACME host + kTLS + single-location proxyPass + websocket proxy.
  #
  # Accepts either:
  #   - `service`: a service name (e.g. "sonarr") — derives host as
  #     "${service}.${baseHost}" and port from
  #     config.services.${service}.settings.server.port
  #   - `host` + `port`: explicit values for services without a standard
  #     settings.server.port option or non-standard hostnames
  #   - `host` + `locations`: explicit values for complex vhosts with multiple
  #     locations or custom location blocks (port not required)
  #
  # `port` accepts an int or string; the helper applies `toString` internally.
  # `locations` accepts a full location attrset for complex vhosts; when provided,
  # the helper uses it verbatim instead of generating a default proxy location.
  # `listen` accepts a list of listen specs for non-standard vhost bindings.
  # `locationExtraConfig` applies extra config to the generated location only.
  # Returns a singleton attrset { "<host>" = { ... }; } suitable for merging
  # into services.nginx.virtualHosts via `//`.
  _module.args.mkNginxVhost =
    {
      host ? null,
      port ? null,
      service ? null,
      baseHost ? null,
      useACMEHost ? "homehub.tv",
      forceSSL ? true,
      kTLS ? true,
      proxyHost ? "127.0.0.1",
      proxyWebsockets ? false,
      locationPath ? "/",
      locationExtraConfig ? "",
      locations ? null,
      listen ? null,
    }:
    let
      resolvedBaseHost = if baseHost != null then baseHost else useACMEHost;
      resolvedHost = if service != null then "${service}.${resolvedBaseHost}" else host;
      resolvedPort = if service != null then config.services.${service}.settings.server.port else port;
      hasCustomLocations = locations != null;
      generatedLocations = {
        ${locationPath} = {
          proxyPass = "http://${proxyHost}:${toString resolvedPort}";
          inherit proxyWebsockets;
        }
        // lib.optionalAttrs (locationExtraConfig != "") { extraConfig = locationExtraConfig; };
      };
      finalLocations = if hasCustomLocations then locations else generatedLocations;
    in
    assert lib.assertMsg (
      resolvedHost != null
    ) "mkNginxVhost: either `host` or `service` must be provided";
    assert lib.assertMsg (
      hasCustomLocations || resolvedPort != null
    ) "mkNginxVhost: either `locations` or `port`/`service` must be provided";
    {
      ${resolvedHost} = lib.filterAttrs (_: v: v != null) (
        {
          locations = finalLocations;
        }
        // lib.optionalAttrs forceSSL { inherit forceSSL; }
        // lib.optionalAttrs kTLS { inherit kTLS; }
        // lib.optionalAttrs (useACMEHost != null) { inherit useACMEHost; }
        // lib.optionalAttrs (listen != null) { inherit listen; }
      );
    };
}

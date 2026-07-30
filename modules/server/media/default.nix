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

  # Reusable nginx reverse-proxy vhost builder.
  # Covers the common pattern across media services:
  #   forceSSL + useACMEHost "homehub.tv" + kTLS + single-location proxyPass.
  # Returns a singleton attrset { "<host>" = { ... }; } suitable for merging
  # into services.nginx.virtualHosts via `//`.
  _module.args.mkMediaVhost =
    {
      host,
      port,
      proxyHost ? "127.0.0.1",
      extraConfig ? "",
      recommendedProxySettings ? false,
    }:
    {
      ${host} = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        kTLS = true;
        locations."/" = {
          proxyPass = "http://${proxyHost}:${toString port}";
          proxyWebsockets = true;
        }
        // lib.optionalAttrs (extraConfig != "") { inherit extraConfig; }
        // lib.optionalAttrs recommendedProxySettings { inherit recommendedProxySettings; };
      };
    };
}

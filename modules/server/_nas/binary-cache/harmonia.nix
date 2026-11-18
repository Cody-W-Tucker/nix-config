# Harmonia serves the NAS's /nix/store as a signed binary cache.
# Clients: hosts/beast/default.nix (substituter + public key).
{ config, ... }:

let
  port = 5000;
in
{
  # Generated with `nix key generate-secret --key-name nas-cache-1`.
  # Public half: nas-cache-1:Uy5hdzmlVo4igOUVu0aZSZz6Y97QLF2ly2sJK21wLPg=
  sops.secrets."nas-cache-signing-key" = { };

  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ config.sops.secrets."nas-cache-signing-key".path ];
    settings = {
      bind = "[::]:${toString port}";
      # Lower than cache.nixos.org (40), so clients try the LAN copy first.
      priority = 30;
    };
  };

  # Tailscale only; the LAN and the internet never see the cache.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}

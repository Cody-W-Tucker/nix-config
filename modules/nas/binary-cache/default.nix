# Binary cache for the other hosts: the NAS serves its store over Tailscale
# and pre-builds every host from `main` each night, so `update` on beast is a
# LAN download instead of an internet download or a local compile.
{
  imports = [
    ./harmonia.nix
    ./nightly-build.nix
  ];
}

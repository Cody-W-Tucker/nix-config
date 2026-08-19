{
  inputs,
  mkNginxVhost,
  pkgs,
  ...
}:

{
  services.mealie = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mealie;
    port = 9000;
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "mealie.homehub.tv";
    port = 9000;
  };
}

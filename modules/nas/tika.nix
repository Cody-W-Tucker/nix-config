{ config, mkNginxVhost, ... }:

let
  inherit (config.codyos.site) domain;
in
{
  services.tika = {
    enable = true;
    listenAddress = "0.0.0.0";
    openFirewall = true;
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "tika.${domain}";
    inherit (config.services.tika) port;
    locationExtraConfig = ''
      proxy_set_header X-Tika-OCRLanguage "chi_sim+eng";
    '';
  };
}

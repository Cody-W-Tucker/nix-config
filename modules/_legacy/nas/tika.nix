{ config, mkNginxVhost, ... }:

let
  inherit (config.codyos.site) domain;
in
{
  services.tika = {
    enable = true;
    listenAddress = "127.0.0.1";
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "tika.${domain}";
    inherit (config.services.tika) port;
    locationExtraConfig = ''
      proxy_set_header X-Tika-OCRLanguage "chi_sim+eng";
    '';
  };
}

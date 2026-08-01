{ mkNginxVhost, ... }:

{
  services.tika = {
    enable = true;
    port = 9998;
    listenAddress = "0.0.0.0";
    openFirewall = true;
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "tika.homehub.tv";
    port = 9998;
    locationExtraConfig = ''
      proxy_set_header X-Tika-OCRLanguage "chi_sim+eng";
    '';
  };
}

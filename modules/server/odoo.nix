{ config, ... }:
let
  domain = "odoo.homehub.tv";
in
{
  # Basic Odoo config.
  services.odoo = {
    enable = true;
    domain = domain;
    # install addons declaratively.
    addons = [ ];
    # add the demo database
    autoInit = true;
  };

  # Enable Let's Encrypt and HTTPS by default.
  services.nginx.virtualHosts.${domain} = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
  };
}

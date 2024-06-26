{ config, pkgs, ... }:

{
  environment.etc."immich-typsense-api-key".text = "12318551487654187654";
  services.immich = {
    enable = true;
    server.typesense.apiKeyFile = "/etc/immich-typsense-api-key";
  };

  services.typesense = {
    enable = true;
    # In a real setup you should generate an api key for immich
    # and not use the admin key!
    apiKeyFile = "/etc/immich-typsense-api-key";
    settings.server.api-address = "127.0.0.1";
  };

  services.postgresql = {
    enable = true;
    identMap = ''
      # ArbitraryMapName systemUser DBUser
      superuser_map      root      postgres
      superuser_map      postgres  postgres
      # Let other names login as themselves
      superuser_map      /^(.*)$   \1
    '';
    authentication = pkgs.lib.mkOverride 10 ''
      local sameuser all peer map=superuser_map
    '';
    ensureDatabases = [ "immich" ];
    ensureUsers = [
      {
        name = "immich";
        ensurePermissions = {
          "DATABASE immich" = "ALL PRIVILEGES";
        };
      }
    ];
  };
}

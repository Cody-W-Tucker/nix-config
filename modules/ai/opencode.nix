{
  # OpenCode web server (nas): one aspect, two halves.
  #  - nixos: the password secret and its systemd EnvironmentFile template, and the nginx
  #    vhost.
  #  - user (through provides.to-users): linger so the user's services survive logout.
  #  - homeManager (delivered to the including host's users through provides.to-users):
  #    programs.opencode with the web server, and the user-level opencode-web service's
  #    EnvironmentFile. It reads the NixOS-rendered `opencode-env` template through
  #    `osConfig`, so the NixOS template and this list entry stay paired by construction.
  # The shared Home Manager harness (modules/harness/_hm/opencode) appends
  # the opencode-langfuse-env template to the same EnvironmentFile list.
  # Including this aspect is the switch; nas includes it, beast includes opencode.remote.
  den.aspects.opencode = {
    nixos =
      { config, mkNginxVhost, ... }:
      let
        inherit (config.codyos.site) domain;
      in
      {
        codyos.homepage.cards.OpenCode = {
          group = "Tools";
          order = 20;
          card = {
            href = "https://opencode.${domain}";
            icon = "opencode";
            description = "OpenCode Web";
          };
        };

        # OpenCode password secret
        sops.secrets."opencode-password" = {
          owner = config.codyos.site.user.name;
        };

        # Runtime env file for OpenCode web service (systemd EnvironmentFile format)
        sops.templates."opencode-env" = {
          content = ''
            OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode-password"}
          '';
          owner = config.codyos.site.user.name;
        };

        # OpenCode nginx virtual host
        services.nginx.virtualHosts = mkNginxVhost {
          host = "opencode.${domain}";
          port = 4096;
          proxyWebsockets = true;
        };
      };

    provides.to-users.homeManager =
      { osConfig, ... }:
      {
        programs.opencode = {
          enable = true;
          web.enable = true;
          web.extraArgs = [
            "--hostname"
            "127.0.0.1"
            "--port"
            "4096"
          ];
        };

        # EnvironmentFile for the user-level opencode-web service:
        #   - opencode-env SOPS template (OPENCODE_SERVER_PASSWORD)
        systemd.user.services.opencode-web.Service.EnvironmentFile = [
          osConfig.sops.templates."opencode-env".path
        ];
      };

    # Allow the user's services (opencode-web) to linger after logout.
    provides.to-users.user.linger = true;
  };

  # opencode.remote: beast's client for the NAS OpenCode server above. The server uses HTTP
  # Basic auth; scope its secret to the explicit remote alias so regular `op` sessions remain
  # local. Included by beast only.
  den.aspects.opencode.remote.provides.to-users.homeManager =
    { osConfig, config, ... }:
    let
      inherit (osConfig.codyos.site) domain;
    in
    {
      sops.secrets."opencode-password" = { };

      programs.zsh.shellAliases.op- = ''
        OPENCODE_SERVER_PASSWORD="$(<${config.sops.secrets."opencode-password".path})" \
        opencode --server https://opencode.${domain}
      '';
    };
}

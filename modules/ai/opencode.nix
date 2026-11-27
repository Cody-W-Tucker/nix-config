{ den, ... }:
{
  den.aspects.beast.includes = [
    den.aspects.opencode.desktop
    den.aspects.opencode.remote
  ];
  den.aspects.nas.includes = [ den.aspects.opencode ];

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

        sops.secrets."opencode-password" = {
          owner = config.codyos.site.user.name;
        };

        sops.templates."opencode-env" = {
          content = ''
            OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."opencode-password"}
          '';
          owner = config.codyos.site.user.name;
        };

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

        systemd.user.services.opencode-web.Service.EnvironmentFile = [
          osConfig.sops.templates."opencode-env".path
        ];
      };

    provides.to-users.user.linger = true;
  };

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

  den.aspects.opencode.desktop.provides.to-users.homeManager =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.opencode-desktop ];
    };
}

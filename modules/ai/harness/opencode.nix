{ den, ... }:
let
  webPort = 4096;
in
{
  den.aspects = {
    beast.includes = [
      den.aspects.opencode.desktop
      den.aspects.opencode.remote
    ];
    nas.includes = [ den.aspects.opencode.web ];

    harness.homeManager =
      { lib, pkgs, ... }:
      {
        programs = {
          zsh.shellAliases.op = "opencode";
          opencode = {
            enable = true;
            enableMcpIntegration = true;
            settings = {
              autoupdate = false;
              small_model = "opencode-go/deepseek-v4.1-flash";
              agents = {
                explore.model = "openai/gpt-6-luna";
                general.model = "openai/gpt-6-luna";
              };
              formatter = true;
              default_agent = "build";
              permission.external_directory = {
                "/nix/store" = "allow";
                "/nix/store/**" = "allow";
              };
              lsp.nix = {
                command = [
                  "${lib.getExe pkgs.nixd}"
                  "--config=${builtins.toJSON { formatting.command = [ (lib.getExe pkgs.nixfmt) ]; }}"
                ];
                extensions = [ ".nix" ];
              };
            };
          };
        };
      };

    opencode = {
      web = {
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
              port = webPort;
              proxyWebsockets = true;
            };
          };

        provides.to-users.homeManager =
          { osConfig, ... }:
          {
            programs.opencode.web = {
              enable = true;
              extraArgs = [
                "--hostname"
                "127.0.0.1"
                "--port"
                (toString webPort)
              ];
            };

            systemd.user.services.opencode-web.Service.EnvironmentFile = [
              osConfig.sops.templates."opencode-env".path
            ];
          };

        provides.to-users.user.linger = true;
      };

      remote.provides.to-users.homeManager =
        { osConfig, config, ... }:
        {
          sops.secrets."opencode-password" = { };

          programs.zsh.shellAliases.op- = ''
            OPENCODE_SERVER_PASSWORD="$(<${config.sops.secrets."opencode-password".path})" \
            opencode --server https://opencode.${osConfig.codyos.site.domain}
          '';
        };

      desktop.provides.to-users.homeManager =
        {
          inputs,
          lib,
          pkgs,
          ...
        }:
        let
          browse = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode-browse;
        in
        {
          home.packages = [
            pkgs.opencode-desktop
            browse
          ];
          programs.opencode.settings.mcp.servers.browse = {
            type = "local";
            command = [
              (lib.getExe browse)
              "mcp"
            ];
          };
        };
    };
  };
}

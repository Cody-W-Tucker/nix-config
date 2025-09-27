{ config, pkgs, ... }:

let
  userDir = "${config.users.users.codyt.home}";
in
{
  sops.secrets = {
    # Obsidian Tool
    "OBSIDIAN_API_KEY" = { };
    # Todoist
    "TODOIST_API_TOKEN" = { };
    # Google Workspace
    "GOOGLE_OAUTH_CLIENT_ID" = { };
    "GOOGLE_OAUTH_CLIENT_SECRET" = { };
  };

  # Docker
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  virtualisation.oci-containers.backend = "docker";

  # TODO: Need to manually restart "systemctl restart docker-mcpo" because the docker service doesn't notice we changed the config file.
  sops.templates."mcpo-config.json".content = builtins.toJSON {
    mcpServers = {
      google_workspace = {
        command = "uvx";
        args = [ "workspace-mcp" ];
        env = {
          GOOGLE_OAUTH_CLIENT_ID = "${config.sops.placeholder.GOOGLE_OAUTH_CLIENT_ID}";
          GOOGLE_OAUTH_CLIENT_SECRET = "${config.sops.placeholder.GOOGLE_OAUTH_CLIENT_SECRET}";
          WORKSPACE_MCP_PORT = "8001";
          USER_GOOGLE_EMAIL = "cody@tmvsocial.com";
        };
      };
      mcp-obsidian = {
        command = "uvx";
        args = [ "mcp-obsidian" ];
        env = {
          OBSIDIAN_API_KEY = "${config.sops.placeholder.OBSIDIAN_API_KEY}";
          OBSIDIAN_HOST = "https://localhost:27124";
        };
      };
      memory = {
        command = "npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-memory"
        ];
        env = {
          MEMORY_FILE_PATH = "/data/memory/memory.json";
        };
      };
      todoist = {
        command = "npx";
        args = [
          "-y"
          "@abhiz123/todoist-mcp-server"
        ];
        env = {
          TODOIST_API_TOKEN = "${config.sops.placeholder.TODOIST_API_TOKEN}";
        };
      };
      chrome-devtools = {
        command = "npx";
        args = [
          "chrome-devtools-mcp@latest"
          "--"
          "--executablePath ${pkgs.google-chrome}/bin/google-chrome"
        ];
      };
    };
  };

  # MCPO converts an mcp server to the openAPI standard
  virtualisation.oci-containers.containers.mcpo = {
    autoStart = true;
    image = "ghcr.io/open-webui/mcpo:main";
    volumes = [
      "${config.sops.templates."mcpo-config.json".path}:/etc/mcpo/config.json:ro"
      "${userDir}/Public:/data/public"
      "${userDir}/.config/mcp:/data/memory"
    ];

    cmd = [
      "--config"
      "/etc/mcpo/config.json"
      "--api-key"
      "top-secret"
    ];

    extraOptions = [
      "--network=host"
    ];
  };
}

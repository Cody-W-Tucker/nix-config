{config, ...}:

let 
userDir = "${config.users.users.codyt.home}";
in
{

  sops.secrets = {
    # Obsidian Tool
    "OBSIDIAN_API_KEY" = { };
    # Todoist
    "TODOIST_API_TOKEN" = { };
    # Sanity CMS
    "SANITY_PROJECT_ID" = { };
    "SANITY_DATASET" = { };
    "SANITY_API_TOKEN" = { };
  };

  # TODO: Need to manually restart "systemctl restart docker-mcpo" because the docker service doesn't notice we changed the config file.
  sops.templates."mcpo-config.json".content = builtins.toJSON {
    mcpServers = {
      mcp-obsidian = {
        command = "uvx";
        args = [ "mcp-obsidian" ];
        env = {
          OBSIDIAN_API_KEY = "${config.sops.placeholder.OBSIDIAN_API_KEY}";
          OBSIDIAN_HOST = "https://127.0.0.1:27124";
        };
      };
      nixos = {
        command = "uvx";
        args = ["mcp-nixos"];
      };
      fileSystem = {
        command = "npx";
        args = [
          "-y"
          "@modelcontextprotocol/server-filesystem"
          "/data/public"
        ];
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
      tmv-sanity-cms = {
        command = "npx";
        args = [
          "-y"
          "@sanity/mcp-server@latest"
        ];
        env = {
          SANITY_PROJECT_ID = "${config.sops.placeholder.SANITY_PROJECT_ID}";
          SANITY_DATASET = "${config.sops.placeholder.SANITY_DATASET}";
          SANITY_API_TOKEN = "${config.sops.placeholder.SANITY_API_TOKEN}";
        };
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
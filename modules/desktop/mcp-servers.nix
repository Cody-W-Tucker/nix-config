{config, ...}:

let 
userDir = "${config.users.users.codyt.home}";
in
{
  sops.secrets."OBSIDIAN_API_KEY" = { };

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
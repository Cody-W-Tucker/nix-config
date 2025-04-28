{
  virtualisation.oci-containers.containers.mcpo = {
    image = "ghcr.io/open-webui/mcpo:main";

    # Mount the JSON config file into the container
    volumeMounts = [
      {
        source = "/etc/mcpo-config.json";
        target = "/config.json";
        type = "ro"; # Read-only for safety
      }
    ];

    # Pass the config.json file location as an argument to the `mcpo` server
    cmd = [
      "--config"
      "/config.json"
    ];

    extraOptions = [ "--network=host" ];

    environment = {
      OBSIDIAN_API_KEY = "15d02c59d760876ed625ec46ddcc7959cf13a489b72c7b50402fd9f4e1f97fd4";
      OBSIDIAN_HOST = "https://127.0.0.1:27124";
    };
  };

  # Write the JSON configuration file directly using Nix
  system.activationScripts.mcpoConfig = ''
    mkdir -p /etc
    echo ${builtins.toJSON {
      mcpServers = {
        obsidian = {
          command = "uvx";
          args = [ "mcp-obsidian" ];
        };
        memory = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-memory" ];
        };
        time = {
          command = "uvx";
          args = [ "mcp-server-time" "--local-timezone=America/New_York" ];
        };
      };
    }} > /etc/mcpo-config.json
  '';
}
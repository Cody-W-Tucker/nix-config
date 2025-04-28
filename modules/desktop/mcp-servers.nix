let
  mcpoConfig = {
    mcpServers = {
      mcp-obsidian = {
        command = "uvx";
        args = [ "mcp-obsidian" ];
        env = {
          OBSIDIAN_API_KEY = "15d02c59d760876ed625ec46ddcc7959cf13a489b72c7b50402fd9f4e1f97fd4";
          OBSIDIAN_HOST = "https://127.0.0.1:27124";
        };
      };
    };
  };

  configJsonFile = builtins.toFile "mcpo-config.json" (builtins.toJSON mcpoConfig);
in
{
  # MCPO converts an mcp server to the openAPI standard
  virtualisation.oci-containers.containers.mcpo = {
    image = "ghcr.io/open-webui/mcpo:main";
    volumes = [
      "${configJsonFile}:/etc/mcpo/config.json"
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
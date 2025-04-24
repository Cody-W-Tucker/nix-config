{

  # MCPO converts an mcp server to the openAPI standard
  virtualisation.oci-containers.containers.mcpo = {
    image = "ghcr.io/open-webui/mcpo:main";
    environment = {
      OBSIDIAN_API_KEY = "15d02c59d760876ed625ec46ddcc7959cf13a489b72c7b50402fd9f4e1f97fd4";
      OBSIDIAN_HOST = "https://127.0.0.1:27124";
    };
    extraOptions = [
      "--network=host"
    ];
    cmd = [
      "--api-key"
      "top-secret"
      "--"
      "uvx"
      "mcp-obsidian"
    ];
  };

}
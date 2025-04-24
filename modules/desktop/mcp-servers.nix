{ config, ...}:

{
  # Get secrets
  sops.secrets = {
    OBSIDIAN_API_KEY = { };
  };

  sops.templates = {
    "mcp_obsidian".content = ''
      OBSIDIAN_API_KEY=${config.sops.placeholder."OBSIDIAN_API_KEY"}
      OBSIDIAN_HOST="https://127.0.0.1:27124"
    '';
  };

  # MCPO converts an mcp server to the openAPI standard
  virtualisation.oci-containers.containers.mcpo = {
    image = "ghcr.io/open-webui/mcpo:main";
    environmentFiles = [
      config.sops.templates."mcp_obsidian".path
    ];
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
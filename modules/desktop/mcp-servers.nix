{pkgs, ...}:

{
  mcp-servers.lib.mkConfig pkgs {
  format = "yaml";
  fileName = "config.yaml";
  
  # Configure built-in modules
  programs = {
    filesystem = {
      enable = true;
      args = [ "/path/to/allowed/directory" ];
    };
  };
  
  # Add custom MCP servers
  settings.servers = {
    mcp-obsidian = {
      command = "${pkgs.lib.getExe' pkgs.nodejs "npx"}";
      args = [
        "-y"
        "mcp-obsidian"
        "/path/to/obsidian/vault"
      ];
    };
  };
}
}
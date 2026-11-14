{
  inputs,
  pkgs,
  ...
}:
{
  services.hermes-agent.extraPackages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd
  ];

  # QMD search goes through the qmd MCP server (mcp/default.nix), whose tool
  # descriptions carry the query grammar, so there is no QMD skill here.
  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "knowledge-tools";
      root = pkgs.linkFarm "hermes-agent-knowledge-skills" [
        {
          name = "research/research-state";
          path = ./research/research-state;
        }
      ];
      mode = "managed";
    }
  ];
}

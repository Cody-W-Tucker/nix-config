{ den, ... }:
let
  agentContext =
    shell:
    builtins.replaceStrings [ "@environment@" ] [ (builtins.readFile shell) ] (
      builtins.readFile ./context/agents.md
    );
  managed = agentContext ./context/managed-shell.md;
in
{
  den.default.includes = [ den.aspects.harness ];

  den.aspects.harness.homeManager =
    { inputs, pkgs, ... }:
    let
      llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      home.packages = with llmPkgs; [
        cursor-agent
        muse-code
        grok
        herdr-core
        tuicr
        spec-kit
        backlog-md
        gnhf
        no-mistakes
      ];

      codyos.harness.skills = {
        gnhf = "${llmPkgs.gnhf}/lib/node_modules/gnhf/skills/gnhf";
        no-mistakes = "${llmPkgs.no-mistakes.src}/skills/no-mistakes";
      };

      xdg.configFile."tuicr/config.toml".source = ./tuicr.toml;

      programs = {
        opencode.context = managed;
        pi-coding-agent.context = managed;
        claude-code = {
          enable = true;
          enableMcpIntegration = true;
          context = managed;
          agents.explore = ./context/explore-agent.md;
          settings = {
            env.CLAUDE_CODE_SUBAGENT_MODEL = "haiku";
            syncClaudeAiSkills = false;
          };
        };
        codex = {
          enable = true;
          enableMcpIntegration = true;
          context = agentContext ./context/minimal-shell.md;
        };
      };
    };
}

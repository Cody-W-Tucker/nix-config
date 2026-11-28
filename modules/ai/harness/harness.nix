{ den, ... }:
let
  context = shellContext: ''
    # Delegation

    Delegate first on nontrivial tasks. Before broad searches or bulk reads, send a cheaper subagent to gather and distill the context. This applies to repo exploration, documentation and history research, long logs, and test output, even when there is only one line of inquiry. Keep simple lookups and answers already in context inline. If delegation is unavailable, do the smallest useful investigation yourself.

    Run independent work in parallel. Delegate bounded drafts, edits, and checks too; give workers a concrete goal, a scope, only the context they need, and a clear deliverable. Ask for a compact answer with findings, decisive file/line or source references, checks run, and uncertainties. Ask for pointers, not transcripts or raw logs. Follow up in the same worker when it already has the evidence.

    Choose the cheapest capable model explicitly when the harness lets you. Use the small tier for research, routine checks, and drafts; move up for work that needs more reasoning or when the cheap pass comes back inconclusive. Prefer a configured cheaper route to an inherited premium model. Respect explicit user model choices and higher-priority harness instructions. Only select models through the OpenCode Go (`opencode-go`) provider when the user explicitly instructs you to do so.

    The parent owns the plan, decisions, and final answer. Verify the evidence that changes the decision and inspect and test delegated edits. Do not redo the worker's full investigation just to verify its summary.

    # Environment

    Unless otherwise stated, you are operating in a NixOS system.

    ${shellContext}

    If direnv blocks the `.envrc` or reports that it failed to load, stop and report the problem. Do not run `direnv allow` yourself or silently use the default tools.
    If there is no `.envrc` and the project has a flake dev shell, use `nix develop --command <command>` unless the project documents a different entry point.
  '';
  managed = context ''
    The harness uses Bash and provides `python3`, `node`, and standard CLI tools. Do not assume project dependencies are installed.

    Set the shell tool's working directory to the project directory. The harness loads its `.envrc` automatically before running each command. If a command changes to another project directory, use `direnv exec . <command>` there or start a new tool call in that directory.

    For a missing one-off tool with no project environment, use `nix shell nixpkgs#<package> --command <tool>` instead of installing it globally.
  '';
  minimal = context ''
    This is a minimal environment. Do not assume system-wide installations of languages or external tools.

    If direnv finds a project `.envrc` in the working directory or a parent, run project commands there with `direnv exec . <command>`.

    If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
    Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

    Examples:
    - Python: nix shell nixpkgs#python3 --command python script.py
    - Node: nix shell nixpkgs#nodejs --command node script.js
  '';
in
{
  den.default.includes = [ den.aspects.harness ];

  den.aspects.harness.homeManager =
    {
      config,
      inputs,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      withMutableSettings =
        program:
        lib.optionalAttrs (options.programs.${program} ? mutableSettings) { mutableSettings = true; };
      claudePlugins = config.codyos.harness.claudePlugins;
    in
    {
      options.codyos.harness.claudePlugins = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.package lib.types.path);
        default = { };
        description = "Claude Code plugins by name; stable Home Manager only accepts them as a list.";
      };

      config = {
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

          codex = {
            enable = true;
            enableMcpIntegration = true;
            context = minimal;
          }
          // withMutableSettings "codex";

          claude-code = {
            enable = true;
            package = llmPkgs.claude-code;
            enableMcpIntegration = true;
            context = managed;
            plugins =
              if builtins.isList options.programs.claude-code.plugins.default then
                lib.attrValues claudePlugins
              else
                claudePlugins;
            agents.explore = ''
              ---
              name: Explore
              description: First pass for repository exploration and gathering context before the parent reads broadly.
              model: haiku
              tools: Read, Glob, Grep
              ---

              Investigate the requested scope without editing. Report concise findings with file and line references, checks run, and any gaps. Do not copy back raw output.
            '';
            settings = {
              env.CLAUDE_CODE_SUBAGENT_MODEL = "haiku";
              syncClaudeAiSkills = false;
            };
          }
          // withMutableSettings "claude-code";
        };
      };
    };
}

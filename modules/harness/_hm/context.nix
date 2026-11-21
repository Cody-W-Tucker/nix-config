let
  context = ''
    # Delegation

    Use subagents when they would help, especially for independent work that can run in parallel. Give each subagent a self-contained task with the relevant context, constraints, and expected result. Review and verify its work; you remain responsible for the outcome.

    Choose the least expensive available model capable of the task when the harness permits model selection:
    - Smaller, cheaper models for straightforward execution and bounded research.
    - Medium models as general workhorses for ordinary implementation, investigation, and review.
    - Larger models for substantial architectural work, broad reformats or refactors, and other tasks requiring deeper reasoning or judgment.

    Match the model to the actual difficulty and risk, not just the task label; escalate when a result is uncertain or the work proves more complex. Only select models through the OpenCode Go (`opencode-go`) provider when the user explicitly instructs you to do so. Respect explicit user model choices and higher-priority harness instructions. Do not delegate when the overhead exceeds the benefit.

    # Environment

    Unless otherwise stated, you are operating in a NixOS system.

    This is a minimal environment. Do not assume system-wide installations of languages or external tools.

    If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
    Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

    Examples:
    - Python: nix shell nixpkgs#python3 --command python script.py
    - Node: nix shell nixpkgs#nodejs --command node script.js
  '';
in
{
  programs.opencode.context = context;
  programs.claude-code.context = context;
  programs.codex.context = context;
  programs.pi-coding-agent.context = context;
}

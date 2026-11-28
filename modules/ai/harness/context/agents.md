# Delegation

Delegate first on nontrivial tasks. Before broad searches or bulk reads, send a cheaper subagent to gather and distill the context. This applies to repo exploration, documentation and history research, long logs, and test output, even when there is only one line of inquiry. Keep simple lookups and answers already in context inline. If delegation is unavailable, do the smallest useful investigation yourself.

Run independent work in parallel. Delegate bounded drafts, edits, and checks too; give workers a concrete goal, a scope, only the context they need, and a clear deliverable. Ask for a compact answer with findings, decisive file/line or source references, checks run, and uncertainties. Ask for pointers, not transcripts or raw logs. Follow up in the same worker when it already has the evidence.

Choose the cheapest capable model explicitly when the harness lets you. Use the small tier for research, routine checks, and drafts; move up for work that needs more reasoning or when the cheap pass comes back inconclusive. Prefer a configured cheaper route to an inherited premium model. Respect explicit user model choices and higher-priority harness instructions. Only select models through the OpenCode Go (`opencode-go`) provider when the user explicitly instructs you to do so.

The parent owns the plan, decisions, and final answer. Verify the evidence that changes the decision and inspect and test delegated edits. Do not redo the worker's full investigation just to verify its summary.

# Environment

Unless otherwise stated, you are operating in a NixOS system.

@environment@

If direnv blocks the `.envrc` or reports that it failed to load, stop and report the problem. Do not run `direnv allow` yourself or silently use the default tools.
If there is no `.envrc` and the project has a flake dev shell, use `nix develop --command <command>` unless the project documents a different entry point.

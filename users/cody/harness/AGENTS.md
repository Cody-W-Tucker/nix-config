# Cody Desktop Harness

Owns Cody's user-session AI/operator harness: OpenCode, Herdr, MCP wiring, local tools, skills, and agent packaging used from the desktop.

Does not own general desktop behavior, shell defaults, host services, or system model services unless the harness is only consuming them.

## Placement Rules

- Put MCP server/client exposure in `mcp.nix` unless it belongs entirely to one packaged tool or skill.
- Put Herdr configuration in `herdr/default.nix` and reusable Herdr module logic in `herdr/module.nix`.
- Put OpenCode agents under `opencode/agents/` and agent-local skills under that agent family.
- Put shared OpenCode skills under `opencode/skills/` only when multiple agents should use them.
- Put custom OpenCode tool plugins under `opencode/tools/`, with implementation files beside their Nix packaging.
- Keep secrets out of this tree; use existing SOPS or secret wrapper plumbing.

## Failure Modes

- Adding an agent, skill, or tool file without importing or tracking it, so the flake cannot see it.
- Duplicating MCP definitions across tools instead of keeping one user-session owner.
- Hiding long shell behavior inside Nix strings when a script or plugin file would be clearer.
- Moving command names, skill paths, or tool names that existing agents reference.

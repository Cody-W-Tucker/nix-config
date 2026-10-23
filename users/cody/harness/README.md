# Cody Desktop Harness

This subtree owns Cody's user-session AI/operator harness: OpenCode configuration, MCP wiring, local tools, and agent/skill packaging used from the desktop.

Central docs should point here for harness implementation detail.

## Entry Points

- `default.nix` — harness import root for the desktop profile.
- `mcp.nix` — user-session MCP server/client wiring.
- `opencode/default.nix` — OpenCode user harness root.

## Stack

| Component             | Tool                                         | Configuration Location                                                                                             |
| --------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Harness root          | Desktop harness import                       | `default.nix`                                                                                                      |
| MCP wiring            | User-session MCP servers and client exposure | `mcp.nix`                                                                                                          |
| Agent runtime surface | OpenCode                                     | `opencode/default.nix`                                                                                             |
| Agent families        | Business, Knowledge, Logging, Verifier       | `opencode/agents/business/`, `opencode/agents/knowledge/`, `opencode/agents/logging/`, `opencode/agents/verifier/` |
| Agent-local skills    | Family-specific skills                       | `opencode/agents/*/skills/`                                                                                        |
| Custom tool plugins   | RTK, other OpenCode tools                    | `opencode/tools/`, `opencode/tools/rtk/`                                                                           |
| Context trimming      | RTK read/context reduction tool              | `opencode/tools/rtk/`                                                                                              |

## Layout Notes

- `opencode/agents/` contains agent definitions grouped by role or operating mode.
- `opencode/agents/*/skills/` contains skills that belong to a specific agent family.
- `opencode/skills/` contains shared OpenCode skills available across agents.
- `opencode/tools/` contains custom OpenCode tool plugins packaged for the user session.

RLM-related behavior is surfaced through the harness and OpenCode tooling rather than a separate top-level user area. Recursive language-model execution and CLI multiplexing for the desktop are represented here through the relevant tool or module files.

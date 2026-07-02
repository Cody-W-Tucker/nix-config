# OpenCode Tools and Skills
Relevant source files
- [users/cody/desktop/harness/opencode/agents/business/skills/crm/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/agents/business/skills/crm/default.nix)
- [users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix)
- [users/cody/desktop/harness/opencode/skills/agent-browser/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/skills/agent-browser/default.nix)
- [users/cody/desktop/harness/opencode/skills/humanizer/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/skills/humanizer/default.nix)
- [users/cody/desktop/harness/opencode/tools/model-router/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/model-router/default.nix)
- [users/cody/desktop/harness/opencode/tools/rtk/plugin.ts](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/rtk/plugin.ts)
- [users/cody/desktop/harness/opencode/tools/voice/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/default.nix)
- [users/cody/desktop/harness/opencode/tools/voice/plugin.ts](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/plugin.ts)

The OpenCode environment is extended through a sophisticated architecture of TypeScript plugins, Nix-managed skills, and Model Context Protocol (MCP) servers. These tools bridge the gap between the LLM's natural language reasoning and the system's execution environment, providing specialized capabilities for voice interaction, remote tool execution, and domain-specific knowledge.

## Tool Plugins

OpenCode plugins are TypeScript modules injected into the agent runtime to provide custom tools or hook into the execution lifecycle.

### Voice Tool (TTS)

The `VoicePlugin` allows OpenCode agents to communicate status updates via the local Text-to-Speech (TTS) pipeline. It interfaces with the `llama-swap` TTS endpoint (typically Kokoro) and uses `mpv` for audio playback [users/cody/desktop/harness/opencode/tools/voice/plugin.ts76-124](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/plugin.ts#L76-L124)

**Key Logic:**

- **VAD Awareness**: The tool checks for an active recording PID file (`/tmp/llama-dictate-recording.pid`) before speaking to avoid overlapping with user speech input [users/cody/desktop/harness/opencode/tools/voice/plugin.ts35-42](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/plugin.ts#L35-L42)
- **Async Playback**: Audio is fetched as a buffer, written to a temporary directory, and spawned via `mpv --no-terminal --really-quiet`[users/cody/desktop/harness/opencode/tools/voice/plugin.ts44-74](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/plugin.ts#L44-L74)
- **Configuration**: Managed via environment variables like `OPENCODE_VOICE_TTS_API_URL` and `OPENCODE_VOICE_TTS_MODEL`[users/cody/desktop/harness/opencode/tools/voice/default.nix18-23](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/default.nix#L18-L23)

### Model Router

The `model-router` plugin manages dynamic model selection across different performance tiers (Fast, Medium, Heavy). It is sourced from an upstream repository and patched during the Nix build process to inject specific model identifiers for the `openai` preset, such as `gpt-5.5-fast`[users/cody/desktop/harness/opencode/tools/model-router/default.nix25-37](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/model-router/default.nix#L25-L37)

### RTK (Remote Tool Kit)

The `RtkOpenCodePlugin` acts as a middleware that intercepts `bash` and `shell` tool calls. It pipes commands through the `rtk rewrite` utility to optimize them for token savings before execution [users/cody/desktop/harness/opencode/tools/rtk/plugin.ts9-39](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/rtk/plugin.ts#L9-L39)

### Tool Data Flow: Voice Interaction

This diagram illustrates how a natural language request to "speak" is translated into system-level audio output.

```

```

**Sources:**[users/cody/desktop/harness/opencode/tools/voice/plugin.ts79-120](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/plugin.ts#L79-L120)[users/cody/desktop/harness/opencode/tools/voice/default.nix18-23](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/default.nix#L18-L23)

---

## Agent Skills

Skills are Markdown-based identity and instruction sets injected into the agent's system prompt. They are managed via the `programs.opencode.skills` Nix option.

### Humanizer Skill

The `humanizer` skill transforms AI-generated text into natural, human-like writing. It is based on Wikipedia's "Signs of AI writing" guide and includes logic for:

- **Pattern Detection**: Identifying inflated symbolism, passive voice, and AI-specific vocabulary [users/cody/desktop/harness/opencode/skills/humanizer/default.nix7-13](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/skills/humanizer/default.nix#L7-L13)
- **Voice Calibration**: Analyzing user-provided writing samples to match sentence length, rhythm, and punctuation habits [users/cody/desktop/harness/opencode/skills/humanizer/default.nix41-61](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/skills/humanizer/default.nix#L41-L61)
- **Personality Injection**: Encouraging the agent to have opinions, acknowledge complexity, and use first-person perspectives [users/cody/desktop/harness/opencode/skills/humanizer/default.nix62-87](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/skills/humanizer/default.nix#L62-L87)

### Domain-Specific Skills

- **Agent Browser**: Integrates the `agent-browser` package, providing `core` and `dogfood` skills for web navigation and interaction [users/cody/desktop/harness/opencode/skills/agent-browser/default.nix1-16](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/skills/agent-browser/default.nix#L1-L16)
- **Google Workspace**: Curates skills for Gmail triage, Drive access, and Calendar management. The `gws-gmail-triage` skill is specifically patched to default to `in:inbox` queries for better agent efficiency [users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix26-54](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix#L26-L54)
- **CRM-CLI**: Provides tools for interacting with the local customer relationship management system via a virtual filesystem [users/cody/desktop/harness/opencode/agents/business/skills/crm/default.nix4-6](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/agents/business/skills/crm/default.nix#L4-L6)

---

## MCP Server Integration

OpenCode utilizes the Model Context Protocol (MCP) to access external tools and context through a standardized interface. These are wired via the `harness/mcp.nix` configuration.

| MCP Server | Functionality | Code Reference |
| --- | --- | --- |
| `context7` | Advanced project-wide context gathering and indexing. | `harness/mcp.nix` |
| `nixos-option-search` | Tool for querying NixOS options and their definitions. | `harness/mcp.nix` |
| `exa` | Enhanced file system listing with metadata and git status. | `harness/mcp.nix` |
| `gh_grep` | GitHub-integrated search for cross-repository code discovery. | `harness/mcp.nix` |

### Skill & Tool Mapping

This diagram bridges the agent's intent to specific Nix-declared skills and their underlying implementations.

```

```

**Sources:**[users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix3-19](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix#L3-L19)[users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix26-54](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix#L26-L54)

---

## Configuration & Activation

OpenCode tools are activated using Home Manager's `activation` blocks to ensure TypeScript plugins are correctly placed in the user's XDG configuration directory.

- **Plugin Deployment**: The `opencodeVoicePlugin` block creates the `$XDG_CONFIG_HOME/opencode/plugins` directory and copies the `plugin.ts` file, ensuring it is writable by the user [users/cody/desktop/harness/opencode/tools/voice/default.nix8-14](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/voice/default.nix#L8-L14)
- **Router Deployment**: The `opencodeModelRouter` block handles the recursive copy of the patched router source and creates a loader shim at `model-router.ts`[users/cody/desktop/harness/opencode/tools/model-router/default.nix43-56](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/users/cody/desktop/harness/opencode/tools/model-router/default.nix#L43-L56)

**Sources:**

- `users/cody/desktop/harness/opencode/tools/voice/plugin.ts`
- `users/cody/desktop/harness/opencode/tools/voice/default.nix`
- `users/cody/desktop/harness/opencode/tools/model-router/default.nix`
- `users/cody/desktop/harness/opencode/skills/humanizer/default.nix`
- `users/cody/desktop/harness/opencode/agents/business/skills/google-workspace/default.nix`
- `users/cody/desktop/harness/opencode/tools/rtk/plugin.ts`
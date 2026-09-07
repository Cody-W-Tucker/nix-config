import type { Plugin } from "@opencode-ai/plugin"

// Injects the real OpenCode sessionID as x-opencode-session on every LLM
// request. Required when the provider baseURL is the homehub LiteLLM proxy
// (ai.homehub.tv): OpenCode only auto-sends this header to opencode.ai hosts.
//
// Two consumers share the value on different hops:
//   - nginx rewrites it to x-litellm-session-id → LiteLLM/Langfuse session.id
//   - LiteLLM forwards x-opencode-session upstream → OpenCode Go prompt cache

const HEADER = "x-opencode-session"

export const SessionHeadersPlugin: Plugin = async () => {
  return {
    "chat.headers": async (input, output) => {
      const sessionID = input?.sessionID
      if (typeof sessionID !== "string" || !sessionID) return
      if (!output.headers || typeof output.headers !== "object") {
        ;(output as { headers: Record<string, string> }).headers = {}
      }
      output.headers[HEADER] = sessionID
    },
  }
}

export default SessionHeadersPlugin

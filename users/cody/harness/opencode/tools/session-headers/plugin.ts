import type { Plugin } from "@opencode-ai/plugin"

// Injects the real OpenCode sessionID on every LLM request. Required when the
// provider baseURL is the homehub LiteLLM proxy (ai.homehub.tv): OpenCode only
// auto-sends x-opencode-session to opencode.ai hosts.
//
// Two consumers, both driven from the same sessionID:
//   - x-opencode-session: forwarded upstream by general_settings
//     forward_client_headers_to_llm_api (any x-* header except x-stainless
//     passes) → OpenCode Go prompt cache affinity.
//   - x-litellm-session-id: extracted natively by LiteLLM into
//     metadata.session_id → langfuse_otel maps it to session.id.

const HEADER = "x-opencode-session"
const LITELLM_HEADER = "x-litellm-session-id"

export const SessionHeadersPlugin: Plugin = async () => {
  return {
    "chat.headers": async (input, output) => {
      const sessionID = input?.sessionID
      if (typeof sessionID !== "string" || !sessionID) return
      if (!output.headers || typeof output.headers !== "object") {
        ;(output as { headers: Record<string, string> }).headers = {}
      }
      output.headers[HEADER] = sessionID
      output.headers[LITELLM_HEADER] = sessionID
    },
  }
}

export default SessionHeadersPlugin

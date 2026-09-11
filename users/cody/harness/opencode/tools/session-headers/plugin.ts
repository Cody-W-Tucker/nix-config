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
// Non-generic, client-identifying UA forwarded upstream to LiteLLM/OpenCode
// Go (nginx passes it through untouched). Without this, the OpenAI SDK's
// generic stainless User-Agent reaches the upstream. Deliberately excludes the
// sessionID: it lives in x-opencode-session and must not leak into UA-keyed
// logs/traces.
const USER_AGENT = "opencode-homehub/1.0 (OpenCode harness session-headers plugin)"

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
      output.headers["user-agent"] = USER_AGENT
    },
  }
}

export default SessionHeadersPlugin

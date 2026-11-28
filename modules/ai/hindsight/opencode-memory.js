// Hindsight auto-retain and auto-recall for OpenCode 2.
//
// Upstream's @vectorize-io/opencode-hindsight (0.2.9) targets the OpenCode 1
// plugin API and fails to load on OpenCode 2 ("Plugin must export a default
// definition with an id and an effect or setup function"). This plugin covers
// both halves:
//
// - Retain: when a turn ends it sends the user and assistant text added since
//   the last retain to the Hindsight API, which extracts facts server-side.
// - Recall: each prompt is used to query the project bank and the shared user
//   bank, and the memories found are appended to that prompt in the model
//   request. Stored history is not changed.
//
// REMOVAL CONDITION: replace with the upstream package once it supports
// OpenCode 2.
//
// @apiUrl@, @bankMap@ and @sharedBank@ are filled in by ./default.nix.
import { execFileSync } from "node:child_process"
import { basename, dirname } from "node:path"

const API_URL = "@apiUrl@"
// Project root -> bank. Other projects use the root directory's name.
const BANK_MAP = @bankMap@
// Cross-project user preferences, recalled alongside the project bank.
const SHARED_BANK = "@sharedBank@"
// Skip turns too small to hold a fact worth an extraction call.
const MIN_CHARS = 200
// A first retain of a long resumed session keeps only the most recent text.
const MAX_CHARS = 60000
// Recall settings mirror the Claude Code integration's defaults.
const RECALL_MIN_QUERY_CHARS = 5
const RECALL_MAX_QUERY_CHARS = 800
const RECALL_MAX_TOKENS = 1024
const RECALL_TIMEOUT_MS = 8000
// Prompts whose recall result is kept so later model calls can repeat it.
const RECALL_KEPT_PROMPTS = 1000
const RECALL_OPEN = "<hindsight_memories>"
const RECALL_CLOSE = "</hindsight_memories>"
const RECALL_PREAMBLE =
  "Relevant memories from past conversations (prioritize recent when conflicting). Only use memories that are directly useful to continue this conversation; ignore the rest:"
const TURN_END = new Set([
  "session.execution.succeeded",
  "session.execution.failed",
  "session.execution.interrupted",
  "session.idle",
])

function projectRoot(directory) {
  try {
    const common = execFileSync("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], {
      cwd: directory,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 2000,
    }).trim()
    // Linked worktrees share the main checkout's .git, so they share a bank.
    if (basename(common) === ".git") return dirname(common)
  } catch {
    // not a git repository, or git is not on PATH
  }
  return directory
}

function bankFor(directory) {
  const root = projectRoot(directory)
  return BANK_MAP[root] || basename(root) || "opencode"
}

// User and assistant prose only. Tool calls, reasoning blocks, and synthetic
// messages are left out: they are bulky, and tool output is where file
// contents and secrets appear.
function turns(messages) {
  const out = []
  for (const message of Array.isArray(messages) ? messages : []) {
    const role = message?.type || message?.role
    if (role !== "user" && role !== "assistant") continue
    if (message.synthetic) continue
    const text =
      typeof message.text === "string"
        ? message.text.trim()
        : (Array.isArray(message.content) ? message.content : [])
            .filter((part) => part?.type === "text" && typeof part.text === "string" && !part.synthetic)
            .map((part) => part.text.trim())
            .filter(Boolean)
            .join("\n")
    if (text) out.push({ id: message.id, role, text })
  }
  return out
}

function unretained(all, lastID) {
  if (!lastID) return all
  const index = all.findIndex((turn) => turn.id === lastID)
  if (index >= 0) return all.slice(index + 1)
  // The last retained message was compacted away: resume at the latest prompt.
  const lastUser = all.findLastIndex((turn) => turn.role === "user")
  return lastUser >= 0 ? all.slice(lastUser) : []
}

function disabled(name) {
  return ["false", "0", "no"].includes((process.env[name] || "").toLowerCase())
}

function isUser(message) {
  return (message?.role || message?.type) === "user" && !message.synthetic
}

function textParts(message) {
  return (Array.isArray(message?.content) ? message.content : []).filter(
    (part) => part?.type === "text" && typeof part.text === "string" && !part.synthetic,
  )
}

function promptText(message) {
  const text =
    typeof message.text === "string"
      ? message.text
      : textParts(message)
          .map((part) => part.text)
          .join("\n")
  return text.trim()
}

function appendMemories(message, block) {
  if (typeof message.text === "string") {
    if (!message.text.includes(RECALL_OPEN)) message.text += `\n\n${block}`
    return
  }
  const parts = textParts(message)
  if (parts.some((part) => part.text.includes(RECALL_OPEN))) return
  const last = parts[parts.length - 1]
  if (last) last.text += `\n\n${block}`
  else if (Array.isArray(message.content)) message.content.push({ type: "text", text: block })
}

async function recallBank(bank, query) {
  const response = await fetch(`${API_URL}/v1/default/banks/${encodeURIComponent(bank)}/memories/recall`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    signal: AbortSignal.timeout(RECALL_TIMEOUT_MS),
    body: JSON.stringify({
      query,
      max_tokens: RECALL_MAX_TOKENS,
      budget: "mid",
      types: ["observation"],
    }),
  })
  if (!response.ok) throw new Error(`Hindsight recall returned HTTP ${response.status}`)
  const results = (await response.json())?.results
  return Array.isArray(results) ? results : []
}

// One block for the prompt, or "" when no bank has anything to say. A bank
// that fails or times out is skipped so the other can still answer.
async function recallBlock(directory, query) {
  const banks = [...new Set([bankFor(directory), SHARED_BANK])]
  const answers = await Promise.allSettled(banks.map((bank) => recallBank(bank, query)))
  const seen = new Set()
  const lines = []
  for (const answer of answers) {
    if (answer.status === "rejected") {
      console.error(`[hindsight-recall] ${answer.reason?.message || answer.reason}`)
      continue
    }
    for (const memory of answer.value) {
      const text = typeof memory?.text === "string" ? memory.text.trim() : ""
      if (!text || seen.has(text)) continue
      seen.add(text)
      const type = memory.type ? ` [${memory.type}]` : ""
      const date = memory.mentioned_at ? ` (${memory.mentioned_at})` : ""
      lines.push(`- ${text}${type}${date}`)
    }
  }
  if (!lines.length) return ""
  const now = new Date().toISOString().slice(0, 16).replace("T", " ")
  return `${RECALL_OPEN}\n${RECALL_PREAMBLE}\nCurrent time - ${now} UTC\n\n${lines.join("\n\n")}\n${RECALL_CLOSE}`
}

async function setupRecall(ctx) {
  // Prompt message ID -> the block recalled for it. OpenCode rebuilds every
  // model call from its store, so each prompt is asked once and its block is
  // appended again on every later call, which also keeps the request prefix
  // stable for prompt caching.
  const recalled = new Map()

  const recall = async (sessionID, query) => {
    try {
      if (query.length < RECALL_MIN_QUERY_CHARS) return ""
      const session = await ctx.session.get({ sessionID })
      // A sub-agent's prompt is written by a parent that already had recall.
      if (!session || session.parentID) return ""
      if (session.location?.directory && session.location.directory !== ctx.location?.directory) return ""
      const directory =
        session.location?.directory || session.directory || ctx.location?.directory || process.cwd()
      return await recallBlock(directory, query.slice(0, RECALL_MAX_QUERY_CHARS))
    } catch (error) {
      console.error(`[hindsight-recall] ${error?.message || error}`)
      return ""
    }
  }

  await ctx.session.hook("context", async (event) => {
    try {
      const users = (Array.isArray(event?.messages) ? event.messages : []).filter(isUser)
      const last = users[users.length - 1]
      if (last?.id && !recalled.has(last.id)) {
        // Stored as a promise so a failure or a concurrent call does not ask twice.
        recalled.set(last.id, recall(event.sessionID, promptText(last)))
        if (recalled.size > RECALL_KEPT_PROMPTS) recalled.delete(recalled.keys().next().value)
      }
      for (const message of users) {
        const block = await recalled.get(message.id)
        if (block) appendMemories(message, block)
      }
    } catch {
      // Memory is optional: never break a session over it.
    }
  })
}

async function setup(ctx) {
  if (!disabled("HINDSIGHT_AUTO_RECALL")) await setupRecall(ctx)
  if (disabled("HINDSIGHT_AUTO_RETAIN")) return
  const retain = async (sessionID) => {
    const session = await ctx.session.get({ sessionID })
    // Sub-agent sessions repeat work their parent session already reports.
    if (!session || session.parentID) return
    // Each location loads its own plugin instance, but subscribes to the
    // server-wide stream. Do not retain another location's sessions too.
    if (session.location?.directory && session.location.directory !== ctx.location?.directory) return

    const key = `retained/${sessionID}`
    const all = turns(await ctx.session.context({ sessionID }))
    const fresh = unretained(all, await ctx.storage.get(key))
    if (!fresh.some((turn) => turn.role === "user") || !fresh.some((turn) => turn.role === "assistant")) return

    const transcript = fresh
      .map((turn) => `[role: ${turn.role}]\n${turn.text}\n[${turn.role}:end]`)
      .join("\n\n")
      .slice(-MAX_CHARS)
    if (transcript.length < MIN_CHARS) return

    const directory =
      session.location?.directory || session.directory || ctx.location?.directory || process.cwd()
    const last = fresh[fresh.length - 1].id
    const response = await fetch(
      `${API_URL}/v1/default/banks/${encodeURIComponent(bankFor(directory))}/memories`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        signal: AbortSignal.timeout(15000),
        body: JSON.stringify({
          async: true,
          items: [
            {
              content: transcript,
              context: "opencode coding session",
              document_id: `opencode-${sessionID}-${last}`,
              tags: ["opencode"],
              metadata: { session_id: sessionID, directory },
            },
          ],
        }),
      },
    )
    if (!response.ok) throw new Error(`Hindsight retain returned HTTP ${response.status}`)
    await ctx.storage.set(key, last)
  }

  const stop = new AbortController()
  const loop = (async () => {
    // One event at a time: a turn can end with more than one of these events,
    // and the second must see what the first already retained.
    for await (const event of ctx.event.subscribe({ signal: stop.signal })) {
      if (!TURN_END.has(event?.type)) continue
      const sessionID = event.data?.sessionID
      if (!sessionID) continue
      try {
        await retain(sessionID)
      } catch (error) {
        // Memory is optional: never break a session over it.
        console.error(`[hindsight-retain] ${error?.message || error}`)
      }
    }
  })().catch(() => {})

  // Await the event loop so `opencode run` does not exit while the retain
  // request for the final turn is still in flight.
  return async () => {
    stop.abort()
    await loop
  }
}

// The ID predates recall. Plugin storage holds the retain cursors, so it stays.
export default { id: "hindsight-retain", setup }

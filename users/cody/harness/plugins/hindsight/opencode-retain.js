// Hindsight auto-retain for OpenCode 2.
//
// Upstream's @vectorize-io/opencode-hindsight (0.2.9) targets the OpenCode 1
// plugin API and fails to load on OpenCode 2 ("Plugin must export a default
// definition with an id and an effect or setup function"). This plugin covers
// the write-back half only: when a turn ends it sends the user and assistant
// text added since the last retain to the Hindsight API, which extracts facts
// server-side. Recall stays on demand through the shared Hindsight MCP server.
//
// REMOVAL CONDITION: replace with the upstream package once it supports
// OpenCode 2.
//
// @apiUrl@ and @bankMap@ are filled in by ./default.nix.
import { execFileSync } from "node:child_process"
import { basename, dirname } from "node:path"

const API_URL = "@apiUrl@"
// Project root -> bank. Other projects use the root directory's name.
const BANK_MAP = @bankMap@
// Skip turns too small to hold a fact worth an extraction call.
const MIN_CHARS = 200
// A first retain of a long resumed session keeps only the most recent text.
const MAX_CHARS = 60000
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

async function setup(ctx) {
  if (["false", "0", "no"].includes((process.env.HINDSIGHT_AUTO_RETAIN || "").toLowerCase())) return
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

export default { id: "hindsight-retain", setup }

import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = (await readFile(new URL("./opencode-retain.js", import.meta.url), "utf8"))
  .replaceAll("@apiUrl@", "http://memory.invalid")
  .replaceAll("@bankMap@", JSON.stringify({ "/etc/nixos": "codyos" }))
const { default: plugin } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)
const user = (id) => ({ id, type: "user", text: "Please preserve this durable project decision. ".repeat(5) })
const assistant = (id) => ({
  id, type: "assistant", content: [
    { type: "reasoning", text: "PRIVATE_REASONING" },
    { type: "tool-result", text: "PRIVATE_TOOL_OUTPUT" },
    { type: "text", text: "The verified project decision is recorded in its configuration." },
  ],
})

async function run({ contexts, parentID, failFirst = false, directory = "/etc/nixos" }) {
  const storage = new Map()
  const writes = []
  let current = 0
  const oldFetch = globalThis.fetch
  globalThis.fetch = async (url, request) => {
    writes.push({ url, body: JSON.parse(request.body) })
    return { ok: !(failFirst && writes.length === 1), status: 503 }
  }
  try {
    const cleanup = await plugin.setup({
      location: { directory },
      storage: { get: async (key) => storage.get(key), set: async (key, value) => storage.set(key, value) },
      session: {
        get: async () => ({ parentID, location: { directory } }),
        context: async () => contexts[current],
      },
      event: { async *subscribe() {
        for (let i = 0; i < contexts.length; i++) {
          current = i
          yield { type: "session.execution.succeeded", data: { sessionID: "test-session" } }
        }
      } },
    })
    await cleanup?.()
    return { storage, writes }
  } finally {
    globalThis.fetch = oldFetch
  }
}

test("retains prose, routes bank, deduplicates events and sends only the next turn", async () => {
  const first = [user("u1"), assistant("a1")]
  const second = [...first, user("u2"), assistant("a2")]
  const { writes, storage } = await run({ contexts: [first, first, second] })
  assert.equal(writes.length, 2)
  assert.equal(writes[0].url, "http://memory.invalid/v1/default/banks/codyos/memories")
  assert.equal(writes[0].body.async, true)
  const text = writes[0].body.items[0].content
  assert.match(text, /project decision/)
  assert.doesNotMatch(text, /PRIVATE_/)
  assert.equal(storage.get("retained/test-session"), "a2")
  assert.match(writes[1].body.items[0].document_id, /a2$/)
  assert.equal(writes[1].body.items[0].content, text)
})

test("failed HTTP request leaves cursor unchanged and is retried", async () => {
  const messages = [user("u1"), assistant("a1")]
  const { writes, storage } = await run({ contexts: [messages, messages], failFirst: true })
  assert.equal(writes.length, 2)
  assert.deepEqual(writes[0].body, writes[1].body)
  assert.equal(storage.get("retained/test-session"), "a1")
})

test("skips child sessions and failed turns without assistant prose", async () => {
  assert.equal((await run({ contexts: [[user("u"), assistant("a")]], parentID: "parent" })).writes.length, 0)
  assert.equal((await run({ contexts: [[user("u")]] })).writes.length, 0)
})

test("resumes after compaction and honors the opt-out", async () => {
  const { writes } = await run({ contexts: [[user("u1"), assistant("a1")], [user("u2"), assistant("a2")]] })
  assert.equal(writes.length, 2)
  const old = process.env.HINDSIGHT_AUTO_RETAIN
  process.env.HINDSIGHT_AUTO_RETAIN = "false"
  try {
    assert.equal((await run({ contexts: [[user("u"), assistant("a")]] })).writes.length, 0)
  } finally {
    if (old === undefined) delete process.env.HINDSIGHT_AUTO_RETAIN
    else process.env.HINDSIGHT_AUTO_RETAIN = old
  }
})

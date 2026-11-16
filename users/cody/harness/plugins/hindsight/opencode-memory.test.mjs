import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import test from "node:test"

const source = (await readFile(new URL("./opencode-memory.js", import.meta.url), "utf8"))
  .replaceAll("@apiUrl@", "http://memory.invalid")
  .replaceAll("@bankMap@", JSON.stringify({ "/etc/nixos": "codyos" }))
  .replaceAll("@sharedBank@", "cody")
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
        hook: async () => {},
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

const prompt = (id, text) => ({ id, role: "user", content: [{ type: "text", text }] })

async function recallRun({ banks = {}, parentID, calls }) {
  const requests = []
  let hook
  const oldFetch = globalThis.fetch
  globalThis.fetch = async (url, request) => {
    const bank = url.match(/banks\/([^/]+)\/memories\/recall$/)?.[1]
    requests.push({ bank, body: JSON.parse(request.body) })
    if (banks[bank] === "fail") return { ok: false, status: 503 }
    return { ok: true, json: async () => ({ results: banks[bank] || [] }) }
  }
  try {
    const cleanup = await plugin.setup({
      location: { directory: "/etc/nixos" },
      storage: { get: async () => undefined, set: async () => {} },
      session: {
        get: async () => ({ parentID, location: { directory: "/etc/nixos" } }),
        context: async () => [],
        hook: async (name, handler) => {
          assert.equal(name, "context")
          hook = handler
        },
      },
      event: { async *subscribe() {} },
    })
    const events = []
    for (const messages of calls) {
      // OpenCode rebuilds the request from its store for every model call.
      const event = { sessionID: "test-session", messages: structuredClone(messages) }
      await hook?.(event)
      events.push(event)
    }
    await cleanup?.()
    return { requests, events, registered: Boolean(hook) }
  } finally {
    globalThis.fetch = oldFetch
  }
}

const sent = (event, index) => event.messages[index].content.map((part) => part.text).join("")

test("recalls once per prompt from the project and shared banks and repeats the block", async () => {
  const first = [prompt("u1", "How is the backup job configured?")]
  const second = [...first, assistant("a1"), prompt("u2", "And where does it send alerts?")]
  const { requests, events } = await recallRun({
    banks: {
      codyos: [{ text: "Backups run nightly.", type: "observation", mentioned_at: "2026-11-01" }],
      cody: [{ text: "Backups run nightly." }, { text: "Prefers short answers." }],
    },
    calls: [first, first, second],
  })
  assert.deepEqual(requests.map((request) => request.bank), ["codyos", "cody", "codyos", "cody"])
  assert.equal(requests[0].body.query, "How is the backup job configured?")
  assert.deepEqual(requests[0].body.types, ["observation"])
  assert.equal(requests[2].body.query, "And where does it send alerts?")
  const text = sent(events[0], 0)
  assert.match(text, /^How is the backup job configured\?\n\n<hindsight_memories>/)
  assert.match(text, /- Backups run nightly\. \[observation\] \(2026-11-01\)/)
  assert.match(text, /- Prefers short answers\./)
  assert.equal(text.match(/Backups run nightly/g).length, 1)
  // The same bytes go out on every later call, including after a new prompt.
  assert.equal(sent(events[1], 0), text)
  assert.equal(sent(events[2], 0), text)
  assert.match(sent(events[2], 2), /<hindsight_memories>/)
})

test("recall leaves the prompt alone when banks are empty, failing, or the session is a child", async () => {
  const messages = [prompt("u1", "How is the backup job configured?")]
  const empty = await recallRun({ calls: [messages, messages] })
  assert.equal(empty.requests.length, 2)
  assert.equal(sent(empty.events[1], 0), "How is the backup job configured?")
  const failing = await recallRun({ banks: { codyos: "fail", cody: [{ text: "Kept." }] }, calls: [messages] })
  assert.match(sent(failing.events[0], 0), /- Kept\./)
  const child = await recallRun({ banks: { codyos: [{ text: "Hidden." }] }, parentID: "parent", calls: [messages] })
  assert.equal(child.requests.length, 0)
  assert.equal(sent(child.events[0], 0), "How is the backup job configured?")
  const short = await recallRun({ banks: { codyos: [{ text: "Hidden." }] }, calls: [[prompt("u1", "ok")]] })
  assert.equal(short.requests.length, 0)
})

test("recall honors the opt-out", async () => {
  const old = process.env.HINDSIGHT_AUTO_RECALL
  process.env.HINDSIGHT_AUTO_RECALL = "false"
  try {
    const { registered } = await recallRun({ calls: [] })
    assert.equal(registered, false)
  } finally {
    if (old === undefined) delete process.env.HINDSIGHT_AUTO_RECALL
    else process.env.HINDSIGHT_AUTO_RECALL = old
  }
})

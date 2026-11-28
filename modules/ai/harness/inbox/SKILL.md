---
name: inbox
description: Leave Cody a note in his Discord inbox when something on this system keeps getting in the way of work — a missing tool, a recurring error, a workaround you had to repeat, or a capability the task needed and the system lacked. Use at the end of a task, not to report the task itself.
---

# Inbox

Cody's inbox is a Discord channel he reads when he chooses. A note there is a request to change the system so the friction stops happening, not a status update.

## When to send one

Send a note when all of these hold:

- The friction comes from the system (CodyOS, the harness, a service, a missing package or permission), not from the task or the code you were asked to change.
- It is likely to happen again: it already recurred, deja shows it in earlier sessions, or the next agent will hit it the same way.
- You did not fix it as part of this task.

Do not send notes for one-off mistakes, for problems you fixed, to summarize your work, or to ask a question you can ask in the conversation. At most one note per distinct problem per session. If unsure, skip it.

## How

```bash
INBOX_FROM=<your harness name> inbox "<what got in the way> — <where you saw it> — <evidence> — <the change that would remove it>"
```

Keep it to one or two lines Cody can act on without opening this session:

- **What:** the friction in plain words.
- **Where:** host, command, or file.
- **Evidence:** the error, or a count from deja (`deja recall`) if it recurs.
- **Change:** the smallest system change that would make it go away, if you know it.

Example:

```bash
INBOX_FROM=opencode inbox "Agent shells have no python3 — beast, any harness — 63 sessions hit 'command not found: python3' (deja) — add python3 to the harness packages or teach the skill to use nix shell"
```

Tell the user in your reply that you left a note.

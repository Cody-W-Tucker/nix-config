# Writing these docs

The book is built with mdBook from `docs/src/`. A push to `main` publishes it to GitHub Pages.

User requests and prompts are the main source of what to put in these documentations, not the code itself. How we got here and what we want is more important than just recapitulating what the code says.

## What a page records

A page records the system **as the user meets it**: what to press, open or run, and what then happens on screen. That is the map. The code, Hindsight and deja hold everything below it: the implementation, the decisions and their reasons, benchmarks, history.

Apply two tests to each sentence:

1. **Is it specific to this system?** Delete general knowledge that a capable NixOS user or a model already has: what Grafana or SSH is, standard LSP keys, what direnv does.
2. **Does the user experience it?** Delete what only the code experiences: option values, port lists, config tables, reasons for a choice. The _Changing it_ table links the files for that.

Keep custom keybinds, addresses, commands that exist only here, flows that cross machines, and results that look like a fault but are intended.

The book is grouped by feature area, not by host. A page names the host only where the user meets the difference.

The one exception to "no reasons" is [The Den layout](den-native-layout.md): why the repo is organized by aspects is part of how you work in it. Agent conventions and recipes go in [`modules/AGENTS.md`](../../modules/AGENTS.md), not in the book.

Keep pages atomic: one feature per page, described by what it does for the user. Do not restate a script's steps; give the command and its visible result. Show a shared component, such as the local models, on the page of each feature that uses it, not on a page of its own.

Say each thing once. Deploy commands are on [Building and updating](getting-started.md); checks are on [Checks and standards](checks.md). Other pages link there. Define a term on the page that uses it. There is no glossary.

Keep operator guidance in this book and repository instructions in the nearest `AGENTS.md`. A local README is for a temporary workaround with a removal condition. Keep source comments for constraints and details that are not obvious from the code, not usage guides or inventories.

When agreed behavior changes, update the page in the same change. If a performance question makes a number part of what the user expects, add that number. Benchmarks otherwise stay in memory.

```mermaid
flowchart LR
    report["'This is weird'"] --> docs["Docs: what should the user see?"]
    docs --> memory["Hindsight / deja: what happened before?"]
    memory --> host["Host: what is it doing now?"]
```

## Page shape

| Section       | Content                                                                |
| ------------- | ---------------------------------------------------------------------- |
| _(intro)_     | One or two sentences: what the user gets, and on which host            |
| Task sections | Actions and their results: keys, commands, URLs, and what then appears |
| Changing it   | "To change" → file                                                     |

Normal behavior is stated implicitly, as the result of an action: "Press `SUPER + Escape` again. The text is typed at the cursor, without fillers." Do not add a separate list of what is normal. A result that the user could mistake for a fault (a delay, a missing item) belongs in the description of the action that causes it.

Add a small diagram only for a flow that the user experiences across components or hosts, for example a scan from beast to Paperless on the NAS.

## Style

ASD-STE100 writing rules for a technical reader:

- One term for one thing. Hosts: "beast" and "the NAS" in prose, `beast` and `nas` in code.
- Procedures: 20 words or fewer per sentence, one instruction per step, imperative. Descriptions: 25 words or fewer.
- Active voice, present tense. Condition before instruction.
- Tables for lookups, numbered lists for sequences.
- No filler and no marketing words.

## Mechanics

- **Add a page:** create `docs/src/<name>.md` (kebab-case), list it in `SUMMARY.md`, `git add` it. An unlisted page is not published. A listed page without a file fails the build.
- **Link to a page:** `[Secrets](secrets.md)`, or with a heading anchor.
- **Link to a repo file:** a path relative to `docs/src/`, for example `../../modules/hosts/nas.nix`. The build rewrites it to a GitHub link and fails if the file does not exist.
- **Diagrams:** ` ```mermaid ` blocks.
- **Preview:** `nix shell nixpkgs#mdbook nixpkgs#jq --command mdbook serve docs --open`.
- **Check:** `nix build .#checks.x86_64-linux.docs` (also part of `nix flake check`).
- **Publish:** [`.github/workflows/docs.yml`](../../.github/workflows/docs.yml) builds on pull requests and deploys on push to `main`. It takes mdBook from the locked `nixpkgs-unstable` revision without evaluating the flake.

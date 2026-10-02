# research-state

Bounded, read-only research-continuity collector (Slice A), the Hermes
judgment layer (Slice B: salience records and draft contracts), the manual
attempt lifecycle (Slice C), and second-object transfer with an optional
useful-surprise handoff (Slice D — no scheduling by design). Supplied
records carry shape/reference validation and JSON+Markdown storage from the
same record. Collection stays deterministic; interpretation is Hermes
judgment. There is no candidate generator, no LLM API, no free-form command
runner, no graph store, and no new database.

## Who consumes and renders the outcome?

**Hermes is the active consumer; the CLI records evidence and renders Markdown;
the operator judges usefulness.** This is a manual workflow in the existing
Hermes conversation, not an autonomous learning service. The operator names
the question and authorizes the scope; Hermes handles the JSON bookkeeping.

| Component | What it actually does |
| --- | --- |
| `collect` | Reads scoped sources and writes packet JSON plus sibling Markdown. Does not select an experiment or load past attempts. |
| Hermes with the `research-state` skill | Reads packets and relevant prior records, proposes a contract, does authorized work using existing tools, and supplies lifecycle records. |
| Store commands and the four attempt stages | Validate supplied records and write immutable JSON + Markdown pairs, printing both paths. Check-command strings are data, not executed checks. |
| Hermes Desktop/chat | Hermes reads the saved files, presents the result with evidence links, and can attach the Markdown. No dedicated results pane or automatic subscription ships here. |
| A later Hermes session | Explicitly opens the prior contract/attempt/artifacts and collects fresh evidence. Saving files does not inject them into the next prompt. |

Records live under `${XDG_STATE_HOME:-$HOME/.local/state}/research-state`
(normally `/home/codyt/.local/state/research-state` on NAS), not `$HERMES_HOME`.
JSON is the complete record; Markdown is an abridged view. Packet Markdown
truncates long excerpts/output; attempt Markdown lists artifact references and
hashes, not all bytes. Read JSON and authorized artifacts for full review.

`research-state render <packet.json>` renders **evidence packets only**. For
contracts, attempts, transfers, and surprises, read the sibling `.md` emitted
by their store commands. Do not re-store merely to open a readable view.

The disabled `ca-decisions` **outcome reader is an input adapter** for future
application-owned CA evidence, not a consumer of these attempt files. It does
not block a manual experiment. No CA ingestion, Langfuse upload, QMD indexing
of this state directory, dashboard feed, or automatic skill/SOUL promotion is
wired here. A CA reader needs a verified source path/schema and safe projection.

## First real experiment: a research continuation handoff

This is **proposed guidance, not authorization or an observed result**. Use the
first working object, `nas-research-continuity`, without changing Nix, CA,
services, or authored ideals.

**Question:** Can a saved, evidence-backed handoff let us resume NAS/CA research
without reconstructing context or confusing installed resources with proven
capability?

**Hypothesis:** A compact handoff joining relevant authored direction,
checkout/pin state, deployment evidence, availability, and unknown outcomes
will answer the current research question more usefully than scattered facts.
Treat this as discovery: whether the join helps remains uncertain.

1. **Bound and authorize.** Hermes drafts a contract using a fresh packet and
   current source passages. A possible operator authorization is:

   > Run one research-continuation experiment. Read only the default
   > research-state scope and the resulting records. Write experiment records
   > and a handoff only under my research-state directory. Use at most 30 minutes,
   > with no new paid services or purchases. Do not edit repos, notes, profiles,
   > or live configuration; do not restart services. Show me the comparison and
   > leave the usefulness decision open for my review.

   Record the actual approval source/time; this quotation is not consent.
   Account for state-directory writes and exact targets in the contract, not
   just “read-only.” Existing model usage is not a claim of zero cost. If more
   sources are needed, record the gap or obtain a scope extension.
2. **Preserve the baseline.** Save the existing answer/handoff, including what
   cannot be answered, and assess the conditions below. Do not invent a failed
   baseline when the existing answer already works. Store salience and contract
   with `--packet`, then `attempt-start` with the real baseline and stored
   contract before producing the experimental handoff.
3. **Exercise the method.** Hermes writes a short `handoff.md`: relevant
   direction, evidenced state, unknowns, and one justified next experiment or
   explicit no-candidate result. This artifact is the reversible change; the
   CLI does not generate it or run the experiment.
4. **Compare and preserve.** Collect an after packet. Retain actual bounded
   handoff/check outputs with provenance and hashes. Use `attempt-import-result`
   with baseline, after packet, frozen contract, saved started record, and
   artifact root. Compare the same condition IDs. If relevant inputs changed,
   record that rather than crediting the method.
5. **Review and decide.** Hermes presents the comparison; the operator reviews
   usefulness. Store `keep`, `revise`, `discard`, or `inconclusive` through
   `attempt-decide`. A valid file or attractive summary does not settle the
   question. Unreviewed usefulness remains unresolved.

Proposed fixed conditions, assessed both before and after:

| ID | Check |
| --- | --- |
| `evidence-grounded` | Relevant direction and factual answers cite readable sources/observations, or explicitly state what is unknown. Record/reference validation passes. |
| `layers-separated` | Checkout vs pin, deployment, availability, and demonstrated outcomes remain distinct. An agreeing pin or running service is not useful work. |
| `next-step-useful` | The operator can resume the actual question and choose a justified next step, or accept an evidenced reason not to proceed. Human review, not a score. |
| `scope-preserved` | No forbidden writes/restarts or unrestricted/sensitive data collection; protected behavior and counterexample survive. |

**Good counterexample:** the handoff is accurate but answers nothing the
operator needs, or costs more effort to maintain than it saves. Revise/discard
rather than redefining “useful.” An adequate baseline may show no improvement.
The agreeing-state counterexample must also survive: never manufacture drift.
Discard the experimental handoff if unwanted; retain the attempt/decision as
honest history unless the operator requests its deletion.

## What later use means

At the next **real** return to this question, provide the saved decision-record
path (or state directory plus working-object ID). For example:

> Resume NAS research from this decided attempt: `<saved-attempt.json>`.
> Read its handoff and contract, refresh the same scoped evidence, and tell me
> what remains usable, what changed, and whether the handoff actually helped.

Hermes reads the prior evidence, uses the handoff to do the real task, and
records what worked or contradicted the decision. `attempt-followup` receives
the baseline, a distinct fresh packet, and the stored **decided** record as
`--prior`. Re-rendering old JSON, manufacturing a later timestamp, or merely
collecting another packet is not use. There is no mandatory next-day cadence;
without a real occasion, fresh use stays pending. Promote a procedure into its
source skill only when use supports it; raw attempts do not become memory.

## What second-object transfer means

After first-object usefulness is demonstrated, try a different question:
**“Is `research-state` merely built, or available through the active system and
exposed to Hermes?”** Use working-object ID `package-deployment-inquiry`.

Transfer the method of joining declared configuration, deployment evidence,
actual interface checks, and unknowns into an actionable handoff. Do not copy
the first object's CA revisions, verdict, or authority.

1. Prepare an alternate scope for the package question: relevant Nix/package/
   skill source passages, NixOS checkout, generation links, and actual
   interfaces. `interfaces` is declared metadata, not an automatic CLI probe;
   Hermes performs separately authorized read-only checks and retains their
   outputs as attempt artifacts. A package inquiry need not include a service.
2. Collect a distinct target packet and verify source constraints against it.
   A build is not installation; PATH in one shell does not prove gateway
   access; a skill in Git does not prove runtime discovery. Keep gaps unknown.
3. If the method fits, create a **new target contract and attempt** and exercise
   it under its own authority. Otherwise retain an evidenced decline or
   insufficient-evidence result. This inquiry implies no activation/restart.
4. Store a transfer record with the target packet and source decided/followed-up
   attempt as `--prior`. Record the adapted relation or the reason to decline.
   A stored `adapted` record alone does not prove target usefulness: cite the
   target attempt and keep `later_contact` pending until actual use.

**Do not run `examples/second-object-scope.json` unchanged as live proof.** It
contains `example-second-object.service`, treats a subdirectory as a repo, and
compares the CA input revision with the NixOS checkout. This is fixture
scaffolding, not meaningful real drift. Remove placeholder services and
unrelated comparisons (`pins.comparisons: []` when none apply). Only compare
a pin with its corresponding upstream checkout. Use the existing scope schema.

## Delivering and resuming a result

After a run, Hermes returns an **Overview**: question, decision/reviewer,
same-condition before/after findings, unknowns/counterexample, authorized next
step (or none), and exact paths to baseline/after packets, contract, decided
attempt, readable `.md`, and artifacts. Later handoffs add followup/transfer
paths. This is a presentation convention, not another report schema.

Read `.md` in any Markdown viewer. Hermes can present it in chat or attach it
with `MEDIA:/absolute/path/file.md`. For another session, supply the decision
path; do not assume directory contents are remembered. Resolve history by
record content (`working_object`, `attempt_id`, `stage`, timestamps), not just
the newest filename. No additional dashboard is needed for this manual loop.

## Commands

```bash
# Collect with the packaged NAS scope (state defaults to XDG research-state)
research-state collect --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state"

# Collect with explicit overrides (overrides replace the matching scope paths)
research-state collect --scope ./scope.json --state-dir ./state \
  --nixos-repo /etc/nixos --ca-repo ~/Projects/Cognitive-Assistant \
  --personal-root ~/Knowledge/Personal --wiki-root ~/Knowledge/wiki

# Render a packet as Markdown (stdout)
research-state render ./state/20261001T120000Z-<id>.json

# Validate a packet file (exit 0 = valid)
research-state validate ./state/20261001T120000Z-<id>.json

# Slice B: validate/store a SUPPLIED salience record (shape, not approval)
research-state salience-validate ./salience.json [--packet ./packet.json]
research-state salience-store ./salience.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" [--packet ./packet.json]

# Slice B: validate/store a SUPPLIED draft contract (shape, not authorization)
research-state contract-validate ./contract.json [--packet ./packet.json]
research-state contract-store ./contract.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" [--packet ./packet.json]

# Slice C: bounded manual attempt lifecycle (same command, never executes checks)
research-state attempt-validate ./attempt.json [--expect-stage started|result|decided|followed_up --packet ./baseline.json --contract ./contract.json --prior ./prior-attempt.json --artifact-root ./evidence]
research-state attempt-start ./attempt.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" --packet ./baseline.json --contract ./contract.json
research-state attempt-import-result ./attempt.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" --packet ./baseline.json --after-packet ./after.json --contract ./contract.json --prior ./prior-attempt.json --artifact-root ./evidence
research-state attempt-decide ./attempt.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" --packet ./baseline.json --after-packet ./after.json --prior ./prior-attempt.json
research-state attempt-followup ./attempt.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" --packet ./baseline.json --fresh-packet ./fresh.json --prior ./prior-attempt.json

# Slice D: second-object transfer + optional surprise handoff (shape, not approval)
research-state transfer-validate ./transfer.json [--packet ./target-packet.json --prior ./source-attempt.json]
research-state transfer-store ./transfer.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" --packet ./target-packet.json --prior ./source-attempt.json
research-state surprise-validate ./surprise.json [--packet ./packet.json]
research-state surprise-store ./surprise.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state" --packet ./packet.json

# Full unit/integration suite (151 tests: Slices A+B+C+D)
python3 -m unittest discover -s packages/system-scripts/research-state/tests -p '*.py' -v

# Focused package-only build (wrapper derivation; no host build, no lock change)
nix build --no-update-lock-file --impure --expr \
  'let flake = builtins.getFlake "/etc/nixos"; pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage /etc/nixos/packages/system-scripts/research-state.nix { inherit pkgs; }'

# Repo evaluation sanity (no build, no lock change; NOT a host build)
nix flake check --no-build --no-update-lock-file

# Second working object: a reviewed real scope, not the fixture unchanged
research-state collect --scope ./reviewed-second-object-scope.json --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state"
```
These command shapes are not a script to paste wholesale: replace bracketed
options and filenames with actual records. Hermes authors the JSON from
evidence; the operator need not hand-fill schemas. Preserve the printed paths:
later `--prior` arguments must name the saved previous stage under the same
state directory, not an arbitrary input draft in `./`. Use `--packet` on
salience/contract stores for live work even though those flags are optional.

Before activation, run the package-only build above with
`--no-link --print-out-paths`, then invoke
`<printed-store-path>/bin/research-state` in place of the bare command.
Hermes can read the in-repo `SKILL.md` explicitly before skill activation;
its presence in Git is not proof of runtime discovery. No host activation is
needed to invoke the already-built package by path.

Storage actions require their baseline/contract/prior references (shape-only
`attempt-validate` keeps them optional): `attempt-start` refuses persistence
without `--packet`/`--contract`, and `attempt-import-result` additionally
requires a previously persisted `started` record via `--prior` under
`--state-dir` — self-asserted timestamps/shape alone never persist.

`collect --help` lists `--scope`, `--state-dir`, `--nixos-repo`, `--ca-repo`,
`--personal-root`, `--wiki-root`. There is no `--out`: every collect persists
an immutable unique timestamped JSON + Markdown packet pair under `--state-dir`
(default `${XDG_STATE_HOME:-$HOME/.local/state}/research-state`). Production
provenance uses the actual current time and hostname; controlled clock
injection exists only in tests, never as CLI backdating.

Overrides are deterministic: `--nixos-repo`/`--ca-repo` must match the
configured `nixos`/`ca` repository ids, and `--personal-root`/`--wiki-root`
must match at least one configured note path under the corresponding default
root (notes under a replaced root are re-rooted, including CA-checkout notes
under `--ca-repo`). An override that matches nothing is a hard error
(`collect` exits 2, e.g. `--personal-root` against a custom scope with no
Personal-rooted notes) — never a silent no-op. Successful overrides are
recorded in `scope_provenance.overrides`.

## Scope schema (`research-state-scope/v1`)

One editable JSON scope lives next to `main.py` and is packaged alongside it
(`packages/system-scripts/research-state/scope.json`); explicit flags override
its paths, nothing is silently shadowed. The default working object is NAS
research continuity:

- `working_object` `{id, description}`
- `repositories` `[{id, path}]` — `nixos` (`/etc/nixos`), `ca` (CA checkout)
- `pins` `{repository, file, inputs, comparisons: [{input, repository}]}` —
  `flake.lock` `cognitive-assistant` vs the `ca` checkout
- `deployment` `{system, user_candidates}` — `/run/current-system` plus
  obtainable Home Manager generation links
- `notes` `[{id, path, line_ranges, role, superseded_by}]` — explicit selected
  passages only (Thesis/Problem/Solution/Market/What-Enables, CA
  Architecture/Crystallization, three wiki orientation notes, CA
  README/Projection-Experiments)
- `services` `[{id, unit, manager}]` — `hermes-agent`, `hermes-backend`,
  `opencode-web` (user units)
- `interfaces` `[]`, `outcome_readers` `[{id, enabled, reason}]`
  (`ca-decisions` disabled: no verified schema), `qmd` `{enabled, queries}`
  (enabled with one bounded `Personal` status query; missing/stale `qmd`
  yields an explicit `unknown` observation + error, never a dropped row)
- `limits` `{timeout_seconds, max_bytes}` — every probe bounded: subprocess
  stdout/stderr are streamed with a byte cap (no `shell`, no unbounded
  `capture_output`), timeouts kill the child

Invalid scopes fail fast (`collect` exits 2) — see
`packages/system-scripts/research-state/tests/test.py`. Packets with duplicate
source/observation ids are invalid (`validate` fails).

## Packet schema (`research-state/v1`)

`packet_id`, `collected_at` (UTC), `host` (actual hostname), `working_object`,
`scope_provenance`, `sources` `[{id, ref, retrieved_at}]`, `observations`
`[{id, kind, source_id, observed_at, layer, facts}]`, `errors` `[]`,
`comparisons` `[{kind, status, left, right}]`.

- Layers: `declared` (checkout/pin/notes), `deployed` (resolved system/user
  generations), `verified_available` (running service, readable outcome),
  `unavailable`, `unknown` (missing source, failed probe, disabled reader).
  Intended/available/exercised/proven stay separate: a running service is
  availability, not completed work or usefulness.
- Observation kinds: `git` (HEAD + dirty path-status metadata including
  bounded untracked paths, never diff bodies, file contents or remote URLs),
  `flake_input` (locked rev), `deployment`, `note`
  (exact selected excerpts + sha256/mtime/frontmatter dates/role/supersession),
  `service` (allowlisted `systemctl show` fields only), `outcome` (allowlisted
  metadata projection), `qmd` (raw bounded status + up to 3 `Personal`
  searches when enabled).
- Comparisons: only `checkout_vs_pin` with status `agree`/`different`/`unknown`;
  `left`/`right` name observation IDs. A dirty tree or pin divergence never
  implies deployment divergence — no deployment comparison is emitted. Unknown
  HM generation and disabled outcome readers are `unknown` observations, not
  proof of absence or success.

## Provenance and states

Each observation carries `observed_at` (= collection time), each source
`retrieved_at`; note `mtime_utc`/frontmatter dates are author metadata, QMD
`Updated … ago` stays a raw string — index age, source age and retrieval time
are never conflated. Missing sources produce explicit `errors` + `unknown`
observations, never dropped rows.

## Privacy

No credentials, environment values, process arguments, message dumps,
clipboard/desktop capture, diff bodies, remote URLs, journal dumps, or
service `Environment`/`ExecStart`. Error diagnostics are single-line and
truncated. State dirs are `0700`, packets `0600`, writes atomic, filenames
unique — packets are never overwritten. No data in Git by default.

Attempt artifacts admit only explicit allowlisted local input formats
(relative `.txt`/`.md`/`.json`/`.jsonl`/`.log` paths under
`--artifact-root`, at most 8 × 16 KiB each, with provenance and `sha256`).
Both `captured_text` bytes and on-disk `--artifact-root` files pass the
same narrow obvious-dump gate, which rejects private-key blocks,
dotenv-style secret assignments (or 3+ `KEY=value` env lines),
credentialed DB URLs, `/proc`/`ps`/`argv` process dumps, stack-trace dumps
(`Traceback …`, `goroutine …`, `Exception in thread`, `Caused by:`, 3+
`at frame(file:line)` entries), and JSON/JSONL payloads with
secret/env-shaped keys. This is an obvious-pattern gate only — general
redaction of arbitrary free text is NOT guaranteed, so never put private
bytes here. Bytes outside the allowed capture scope are never ingested:
preserve references+hashes with `bytes_outside_scope` instead, and never
ingest a full private log in the name of proof.

## Implementation vs live validation

Fixture tests prove mechanics only. **Real NAS collection has also been
performed**, separately from those tests:

- Collected at `2026-10-02T01:12:37.604212Z`, host `nas`.
- Packet ID `c00dc4cf15dd4b409338e54861aa13bd`.
- JSON: `/home/codyt/.local/state/research-state/2026-10-02T011237604212Z-c00dc4cf15dd.json`;
  sibling `.md` is its readable view. Runtime evidence remains outside Git.
- 24 observations, zero recorded probe errors; CA checkout/pin `agree`.
  Two selected Home Manager generation links and the disabled CA outcome reader
  are explicitly `unknown`, not successes or proof of absence.
- On `2026-10-02`, the retained packet revalidated and its packaged rendering
  matched the saved Markdown exactly. Revalidation is not fresh collection.

This proves collection and the agreeing-state path at its timestamp, **not**
current state, an authorized experiment, later usefulness, or transfer.
Collect a fresh packet for new work. The 151-test suite and package build also
passed on `2026-10-02`. Full host build/activation remain unverified by this
work; the earlier Nix-wide check was blocked by Beast's unrelated invalid
`base16-schemes` derivation, reproduced on pre-work commit `bdf0d4e0`.

Ready-to-run live collection command for Hermes/operator:

```bash
research-state collect --state-dir "${XDG_STATE_HOME:-$HOME/.local/state}/research-state"
```

## Gates and activation handoff (updated for Slice D)

- Collector + salience/contract/attempt/transfer/surprise mechanics
  implemented + full suite green (151 tests; see Tests above).
- Live NAS collection and agreeing-state validation demonstrated at the
  timestamp above; refresh evidence before a new experiment.
- Second real working-object live gate (pending): Hermes/operator collects
  a real second-object packet under an explicit alternate scope, chooses a
  target contract, and records a real transfer (adapt or decline with
  evidence). Fixture agreement is not usefulness.
- Pending chosen authorized experiment on the first loop (unchanged).
- Repository edits are not live until activation; the operator runs
  system/Home Manager activation. No host rebuild/activation was performed
  here (only package-adjacent build, flake evaluation, and focused tests).
  Post-build collection (before activation) is allowed for the operator:
  `research-state collect` writes only to the XDG state dir, never to Git.

## Cleanup, disposal, and source of truth

- Test artifacts live only under repo-local `.salience-*` temp dirs and
  are removed by test cleanup; never scatter fixtures elsewhere. Real
  packets/contracts/attempts/transfers live in the XDG state dir
  (`0700`/`0600`), outside Git, as immutable timestamped JSON+Markdown
  pairs — dispose by deleting the state files (reversal paths are recorded
  per contract/attempt, never executed by this tool).
- Unavailable evidence handling: missing sources produce explicit `errors`
  + `unknown` observations (never dropped rows); disabled outcome readers
  and unknown HM generations are `unknown`, not empty results; transfers
  decline with evidence rather than inventing it.
- Hermes skill source of truth is the Nix source
  (`modules/services/hermes-agent/skills/knowledge/research/research-state/SKILL.md`,
  wired via `skills/knowledge/default.nix`); edit there, never runtime
  copies. Pending activation: skill/CLI changes take effect only after the
  operator activates system/Home Manager.

## Tests

```bash
python3 -m unittest discover -s packages/system-scripts/research-state/tests -p '*.py' -v
```

Covers: agreeing state (no false discrepancy), CA checkout-vs-pin mismatch
labeled correctly (not deployed drift), dirty tree vs unchanged deployment,
unavailable Git/lock/systemctl/QMD, unreadable notes, timeouts, output caps,
missing user generation, unknown outcomes, allowlisted service/outcome
projections, range-excluded private text, CLI overrides, JSON/Markdown
equivalence, `0600`/`0700` immutable unique writes, packet validation, and
fail-fast invalid scopes — plus Slice B: known refs accepted / dangling refs
rejected (salience and contract), no-candidate / insufficient-evidence
accepted with named gaps, incomplete authority and missing
protected-behavior/counterexample rejected as executable contracts,
unresolved prerequisites blocking `supported` capability claims (discovery
stays `unsupported` with explicit `uncertainty`), declared-only service
existence rejected as usefulness proof, input snapshots keeping provenance
and historical/superseded status, salience/contract JSON+Markdown store
round-trips, and skill packaging (linkFarm member + workflow docs) — plus
Slice C: staged attempt start/import/decide/followup with baseline-first
ordering, frozen contract hash + condition IDs, real-byte artifacts with
provenance, keep/decide gates, retained failures, dropped-idea reopen
links, fresh-use packets, and never-executed check commands — plus Slice D:
distinct second-object packet via an alternate scope, valid adaptation and
intentional decline on unknown prerequisites/unverified interfaces,
failed-source masquerade and blind-copy rejections, dropped-reopen
new-evidence rules, legitimate no-change, surprise handoff with no score,
and scheduling absence.

## Slice B — salience records and draft contracts

One salience record (`research-salience/v1`) names the working object,
linked packet/source IDs, source-backed direction, decisions/boundaries/open
questions, observations kept distinct from interpretations, and a small
candidate set (typically 0–3) with compatible interfaces, access constraints,
actual evidence, prerequisites (`verified`/`missing`/`unknown`), why-now,
alternatives, and disconfirming evidence. It may finish honestly with
`no_candidate` or `insufficient_evidence` plus named gaps — empty is valid.
Input snapshots carry `ref`, `retrieved_at` provenance, and boolean
`superseded` (superseded direction stays readable history, never current
instruction).

One draft contract (`research-contract/v1`) links a chosen
candidate/packet, declares a `capability` or `discovery` experiment type,
and records intended capability, computer evidence, retained unresolved
prerequisites, pre-results hypothesis, mechanism, baseline plan, acceptance
conditions with stable IDs (executable `command` where safe, explicit
`human_review` otherwise), falsifying evidence, protected behavior, a GOOD
counterexample, exact read/write authority with bounded targets, cost/time
limits, reversal/disposal, and a pending human gate when
consequential/ambiguous. `status` stays `draft`: a draft never authorizes
execution, and shape validation is not approval.

Reference validation (`--packet`) rejects dangling `source_id` /
`observation_id` refs and packet-ID mismatches (re-link to a fresh packet).
Missing sources or unresolved prerequisites block `supported` capability
claims without blocking honest `unsupported`/discovery proposals; a
`supported` claim needs cited packet observations beyond prose, and
declared-only service existence can never establish usefulness. Discovery
experiments require explicit `uncertainty` and can never claim `supported`.

An in-repo example draft lives at
`packages/system-scripts/research-state/examples/discovery-join-draft.json`:
a bounded read-only discovery of whether intended→deployed→available
evidence can be joined, grounded in Thesis lines 32–38 with an agreeing CA
checkout/pin snapshot and an `unknown` deployed-correspondence prerequisite.
It is an example/draft requiring a fresh packet and review — NOT an
authorized or complete result.

The Hermes skill source is
`modules/services/hermes-agent/skills/knowledge/research/research-state/SKILL.md`,
wired as linkFarm member `research/research-state/SKILL.md` in
`modules/services/hermes-agent/skills/knowledge/default.nix` (managed
`knowledge-tools` pack). Its workflow: collect/load packet, check freshness
and supersession, ground with QMD + direct reads, select one possibility or
explicit no-candidate, scrutinize a counterexample, form the contract, ask
only for genuine authority/meaning boundaries, never execute merely because
shape validates.

## Slice C — manual attempt lifecycle

One attempt record (`research-attempt/v1`) moves through four bounded manual
actions behind the same command; each action validates exactly one stage
shape and persists a new immutable JSON + Markdown pair (attempts are never
overwritten, backdated, or edited in place):

1. `attempt-start` — register the hypothesis plus an immutable contract
   snapshot/hash (`contract_id`, `sha256` over the canonical contract JSON,
   frozen `acceptance_ids`) and freeze baseline input/output refs, the
   baseline packet, and condition IDs — before any results exist. Early
   results are rejected.
2. `attempt-import-result` — capture post-experiment real evidence observed
   after the baseline: revisions, deployed-state refs, host, failures, costs,
   same-condition before/after checks (`pass`/`fail`/`unknown`/
   `review_required`), and bounded allowlisted artifacts (relative
   `.txt`/`.md`/`.json`/`.jsonl`/`.log` paths under `--artifact-root`, at
   most 8 × 16 KiB, each with provenance and `sha256`; `captured_text` bytes
   must hash exactly, otherwise only references+hashes are preserved with
   `bytes_outside_scope`). Secret/env/trace/process-dump names, absolute
   paths, `..` segments, and symlink escapes are rejected, and so are
   obvious dump contents (private-key blocks, secret `KEY=value` env lines,
   credentialed DB URLs, `/proc`/`ps`/`argv` process dumps, stack-trace
   dumps, secret-shaped JSON keys — narrow patterns only, never a general
   redaction promise). Acceptance-check
   `command` strings are recorded data and are never executed by this tool.
3. `attempt-decide` — record `keep`/`revise`/`discard`/`inconclusive` with
   evidence refs, rationale, named reviewer, authority source/status,
   unresolved unknowns, and explicit manual-review provenance
   (`required` + `reviewer` + `checked_at` + `note`: a JSON boolean is never
   human consent). `keep` is rejected with unknown/unreviewed-human/failed
   checks, failed protected behavior, a dropped counterexample, unresolved
   unknowns, changed inputs, or a review that predates the evidence.
   Failures and discarded attempts persist as attempt history, never as
   successful precedent.
4. `attempt-followup` — record fresh use against a fresh packet ID (distinct
   from the baseline packet and first post-test contact). A discarded idea
   stays dropped unless the followup carries an explicit `reopens` link plus
   `new_evidence`. A changed hypothesis or contract/condition set starts a
   new attempt; `--prior` enforces same-lineage, same-hypothesis, forward
   time.

Reference flags (`--packet` baseline, `--after-packet`, `--fresh-packet`,
`--contract`, `--prior`, `--artifact-root`) reject dangling files, changed
baselines/contracts, packet-ID mismatches, lineage breaks, manufactured
timestamps, and hash mismatches. Attempt metadata must exclude secrets
(redaction of arbitrary free text is not guaranteed, so never put it here).

Mechanics/integration proof lives in
`packages/system-scripts/research-state/tests/test_attempt.py`: a complete
fixture attempt whose artifact bytes come from a real sandbox command, plus
rejection paths for every rule above. It proves record mechanics only.

The real first-loop gate remains: fresh NAS packet, Hermes/operator chooses
contract, authority is explicit, baseline kept, real authorized reversible
action, outputs compared, human semantic check, decision, later fresh use.
The proposed handoff experiment needs only state-directory writes; external
repo, live Nix, CA, profile, or service changes require separate authority.
Retain real records in the XDG state directory, not a hypothetical
`docs/results` tree. Live validation of this loop is still pending.

## Slice D — second-object transfer before scheduling

One transfer record (`research-transfer/v1`) exercises a DISTINCT second
working object through the same scope/packet/contract/attempt interfaces —
an explicit alternate scope, never a second config mechanism, and no
hardcoded first-object names (any two working-object ids work; they must
differ). It carries the source attempt and its constraints
(`source.attempt_id/packet_id/decision/working_object/relation`), the
source-status/applicability check (`applicability` with
`verified`/`missing`/`unknown`), and exactly one outcome:

- `adapted` with `adaptation` (how the relation was re-scoped) — only when
  every applicability check is `verified`, no interface is unverified, and
  the source decision is `keep`/`revise` (a `discard`/`inconclusive` source
  needs explicit `reopens: true` plus non-empty `new_evidence` — mere new
  cadence is not enough);
- `declined`/`insufficient_evidence` with `decline.reason` (decline with
  evidence when target prerequisites are unknown or an interface is
  unverified — never copy the first contract blindly);
- `no_change` with `note` (no meaningful change is a first-class legitimate
  result; no obligation to fill a cadence).

`transfer-store` requires `--packet` (the target/second-object packet:
evidence must cite target-packet refs, not reused first-object evidence)
and `--prior` (the source attempt: attempt id, decision/outcome, and
working object must match — failed/inconclusive sources stay history).
`later_contact` (`pending`/`confirmed`/`contradicted`) records the later
confirming/contradicting contact still owed.

One optional surprise record (`research-surprise/v1`) is a separate
operator handoff: the unasked connection, why now, the operator call
(`recognized`/`rejected`/`unknown` — silence is `unknown`, never
recognition), and later contact. Surprise is never scored:
`score`/`surprise_score` keys are rejected in both records.

Mechanics/integration proof lives in
`packages/system-scripts/research-state/tests/test_transfer.py`: a second
fixture object (distinct repo id, system service manager, non-empty
interfaces) collecting a distinct agreeing packet; a valid adaptation
stored via the CLI with `0600`/`0700` round-trip; an intentional decline
when target prerequisites are unknown; failed-source masquerade,
blind-copy, same-object, reused-evidence, and prior-mismatch rejections;
dropped-reopen rules; surprise no-score rules; and scheduling-absence plus
no-`/proc`-substitute gates. An alternate example scope lives at
`packages/system-scripts/research-state/examples/second-object-scope.json`.

Scheduling is deliberately absent: no timer, cron, scheduler module,
dashboard, daemon, or background collection ships in any slice. Scheduling
is optional future work only AFTER manual usefulness is actually shown.

## Acceptance criteria matrix (all nine)

Fixture tests prove mechanics only. The real NAS packet supports the
agreeing-state criterion and part of state separation; other live gates
remain open. No row is marked complete from fixtures.

| # | Criterion | Exact automated test | Source evidence | Live evidence / remaining gate |
| - | --------- | -------------------- | --------------- | --------------------------------- |
| 1 | Working-tree changes distinguished from deployed configuration | `test.py`: dirty-tree vs unchanged deployment; `test_transfer.py::test_second_scope_collects_distinct_packet` (second object keeps the same split) | `main.py` `collect_git` (HEAD + dirty path-status metadata) vs `collect_deployment` (resolved generations); comparisons are `checkout_vs_pin` only, never deployment drift | First NAS packet retains Git/system-generation evidence separately; user-generation correspondence and second-object live proof remain pending |
| 2 | Availability vs completed work vs demonstrated usefulness | Slice A service-layer tests; Slice B declared-only-service rejection; `test_transfer.py::test_decline_when_target_prerequisites_unknown` (decline claims nothing useful) | `collect_service` layer mapping (`verified_available` = running only); `validate_transfer` decline rules | Authorized experiment + usefulness decision on real objects |
| 3 | Real plan-vs-live discrepancy detected with evidence refs | `test.py`: CA checkout-vs-pin mismatch names `left`/`right` observation IDs | `collect_packet` comparison builder (`different` with evidence refs) | Real NAS packet showing an actual `different` comparison |
| 4 | No invented discrepancy when sources agree | `test.py` agreeing-state tests; `test_transfer.py` second-scope `agree` comparison | Same comparison builder (`agree` path) | Demonstrated for first object by live packet `c00dc4cf15dd4b409338e54861aa13bd`; not a claim about current or second-object state |
| 5 | Prerequisites verified, missing ones marked | Slice B prerequisite/capability tests; `test_transfer.py`: adapted-blocked-on-unknown, `insufficient_evidence` naming | `validate_transfer` applicability rules (`verified` gate for `adapted`) | Hermes/operator checking real target prerequisites |
| 6 | Unsupported claims refused, collection failures retained | Slice A/B failure-retention tests; `test_transfer.py::test_failed_source_cannot_masquerade_as_precedent`, prior-mismatch, reused-evidence rejections | Collector `errors` + `unknown` observations; transfer validators | Real collection failures cited; a real declined transfer |
| 7 | Contract linked to authored direction + computer evidence | Slice B ref tests + `examples/discovery-join-draft.json`; `test_transfer.py` target-packet linkage | `validate_contract`/`check_*_refs`; `check_transfer_refs` | Hermes-authored contract on a fresh packet; a target contract for the second object |
| 8 | Real outputs + decision preserved without rewriting the ideal | Slice C lifecycle tests; `test_transfer.py`: store round-trip, dropped-reopen rules; surprise pending shape | `persist_attempt`/`persist_transfer`/`persist_surprise` (immutable JSON+Markdown) | Real authorized reversible experiment, real decision, real transfer record, real surprise handoff |
| 9 | Regression/counterexample check | Slice C protected-behavior/counterexample keep-blocks; `test_transfer.py`: `no_change` legitimate, `later_contact` pending, dropped-stays-dropped | Validators + `later_contact` (`confirmed`/`contradicted` need packet/note) | Fresh-use packet + later confirming/contradicting contact on both objects |

## Files

- `packages/system-scripts/research-state/main.py` — stdlib-only collector
- `packages/system-scripts/research-state/scope.json` — the one editable scope
- `packages/system-scripts/research-state.nix` — wrapper (Python, git,
  systemd on `PATH`; installed via `packages/system-scripts/default.nix`)
- `packages/system-scripts/research-state/tests/test.py` — Slice A fixture tests
 - `packages/system-scripts/research-state/tests/test_salience.py` — Slice B
   fixture tests (refs, no-candidate, authority/protected/counterexample,
   prerequisite/capability vs discovery, provenance/supersession, storage,
   skill packaging)
  - `packages/system-scripts/research-state/tests/test_attempt.py` — Slice C
    fixture tests (full lifecycle with real sandbox command output labeled
    mechanics/integration; baseline-before-result, same-condition comparison,
    protected/counterexample blocks on keep, unknown/missing checks, changed
    inputs/contract, real-bytes vs fabricated artifacts, chronological
    tamper, secret exclusion, path confinement + symlink escapes, no
    overwrite, retained failures/discards, dropped-idea reopen rules,
    manual-review vs deterministic checks, fresh-use packets, no arbitrary
    execution)
  - `packages/system-scripts/research-state/tests/test_transfer.py` — Slice D
    fixture tests (distinct second object via an alternate scope with
    system service manager and interfaces; valid adaptation CLI store
    round-trip; intentional decline on unknown prerequisites/unverified
    interfaces; failed-source masquerade, blind-copy, same-object,
    reused-evidence, and prior-mismatch rejections; dropped-reopen
    new-evidence rules; legitimate no-change; surprise handoff with no
    score; scheduling absence; no `/proc` substitute)
- `packages/system-scripts/research-state/examples/discovery-join-draft.json`
  — example draft discovery contract (Thesis 32–38, agreeing checkout/pin,
  unknown deployed correspondence; draft only, not authorized)
- `packages/system-scripts/research-state/examples/second-object-scope.json`
  — example alternate scope for a second working object
  (package-deployment inquiry with a system service manager and an explicit
  interface; example only, not live evidence)
- `modules/services/hermes-agent/skills/knowledge/research/research-state/SKILL.md`
  — Hermes interpretation skill

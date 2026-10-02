# Salience implementation plan

Status (2026-10-02): slices A–D mechanics implemented in `2c7d92e2`, with
151 passing tests and a successful package build. Real NAS collection is
verified; an authorized first experiment, fresh use, and second-object
transfer remain pending. Full host build/activation are not verified by this
work. Implemented mechanics are not demonstrated usefulness.

Operator guidance, consumption/rendering paths, a concrete proposed first
experiment, and current evidence: [research-state guide](research-state.md).

## Aim

Connect the actual computer to the authored ideals of Cognitive Assistant and the Self-Improving OS. Develop ideal-directed resource mastery: recognize, compose, and reshape available resources into worthwhile outcomes, while letting actual contact correct our understanding of what is worthwhile.

Salience is why a fact or resource combination matters to this work now. It is not frequency, novelty, utilization, or an inferred obligation. All resources are eligible for consideration; using all resources is not the goal. NixOS is the computer being improved, not just the deployment target.

## Governing sources

Read relevant authored passages directly; retain citations, freshness, and supersession. Do not treat historical notes as current instructions merely because retrieval finds them.

Personal root: `/home/codyt/Knowledge/Personal`.

- `Ideas/_Self Improving OS/Thesis and Architecture.md`
- `Ideas/_Self Improving OS/01-Core-Vision/What This System Enables.md` — historical vision; follow its named superseding documents when assessing current direction.
- `Ideas/_Cognitive Assistant/Cognitive Assistant Architecture.md`
- `Ideas/_Cognitive Assistant/Cognitive Assistant Crystallization Loop Project Spec.md`

Wiki orientation under `/home/codyt/Knowledge/wiki`: `concepts/recursive-self-improvement.md`, `concepts/stanza-graph.md`, and `concepts/capability-actualization.md`.

Do not revive historical closeout rituals or subconscious-validation goals, use pathology-weighted profiles as the operator's will, or rewrite the ideal to make a proposal appear aligned. The existing weekly business review remains a separate loop.

## First scope

Research continuity on NAS: join authored direction, `/home/codyt/Projects/Cognitive-Assistant`, `/etc/nixos`, deployment evidence, relevant interfaces, and research outcome records. Distinguish intended, available, exercised, and proven capability. Produce one newly reachable experiment or an honest insufficient-evidence result. Do not attribute NAS observations to Beast.

## Salience aspects

### 1. Direction-relative relevance

Retrieve a small packet containing the working object, relevant ideal, decisions, boundaries, open questions, and superseded interpretations. Use QMD to locate passages and direct reads to ground claims. Record retrieval time; index age and source-note age are different. Do not load the entire identity corpus or infer psychological state.

### 2. Grounded resource affordances

Read selected evidence:

- Nix/Git revisions, dirty state, relevant configuration, and pinned inputs.
- Active system generation and obtainable user deployment evidence.
- Named service states, last execution results, schedules, and safe interface metadata.
- Available CLI/API operations, accepted inputs, produced outputs, and access constraints.
- Relevant project artifacts and application-owned outcome records.

Separate declared, deployed, verified available, unavailable, and unknown. Installed software is not a working integration; a healthy service is not a useful outcome. Preserve source references, timestamps, probe errors, and missing permissions.

### 3. Resource composition and opportunity

Hermes connects verified resources to the working object. Candidates may remove friction, connect existing pieces, simplify an arrangement, or enable an experiment. Each names compatible interfaces, constraints, evidence, and why it matters now. Separate observations from interpretations. Do not invent missions from idle hardware or manufacture a gap to justify work. Start with a small candidate set, not exhaustive mission generation.

### 4. Alignment warrant

Write one experiment contract:

- Source-backed direction and chosen capability.
- Computer evidence and unresolved prerequisites.
- Hypothesis and proposed mechanism.
- Acceptance conditions and falsifying evidence.
- Protected behavior and a good counterexample.
- Read/write authority, bounded scope, and reversal/disposal path.

Distinguish capability experiments (test a chosen performance) from discovery experiments (resolve uncertainty about what is possible or worthwhile). The warrant is conditional and local, not a guarantee that the experiment succeeds or that the direction is universally necessary. Automated scores nominate candidates; they do not establish intent or approve their own proposals.

### 5. Comparable actualization

Preserve a baseline, then exercise the authorized experiment. Retain real outputs, inputs, revisions, deployed state, failures, and relevant costs. Compare the same acceptance conditions before and after, preserve counterexamples, and check fresh use. Use local capability measures, not a universal alignment score. Langfuse response contracts do not establish project-arc forecasting or useful surprise.

### 6. Attempt memory and reconciliation

Record the hypothesis before results arrive. Retain keep, revise, discard, or inconclusive with evidence. Failures remain attempt history, not successful precedent. Separate durable procedure, current context, and superseded interpretation. Promote demonstrated procedures into skills at their source of truth; promote arrangements into Nix only when persistence is warranted. Never automatically rewrite SOUL, ideals, or memories from judge scores. Keep dropped ideas dropped unless new evidence changes their basis.

### 7. Transfer and useful surprise

After the first loop works, test another working object. Assess whether a learned resource relationship can be adapted or appropriately declined, rather than copied blindly. A script proves one capability; successful recombination provides evidence of mastery. An unasked connection is a separate handoff for the operator to recognize or reject; preserve later confirming or contradicting contact. Surprise itself is not a score.

## Minimal implementation

- One manual command, proposed name `research-state`, packaged through the existing `packages/system-scripts` convention.
- One editable scope definition naming repositories, selected notes, services, permitted interfaces, and outcome readers.
- JSON evidence packet and concise Markdown rendering from the same facts.
- Timestamped packets, contracts, and attempts in mutable XDG state outside Git by default. Choose the explicit runtime path during implementation.
- One Hermes skill for packet interpretation, contract formation, and outcome reconciliation, persisted at the appropriate source rather than only a managed runtime copy.

Configured paths are defaults; explicit arguments override them. Collection is deterministic; interpretation uses Hermes judgment; acceptance checks are executable where possible and explicitly reviewed where not.

Collect no credentials, environment values, full process arguments, private message dumps, clipboard contents, or unrestricted desktop activity. Use safe field projections and supported read-only APIs. Inaccessible evidence is unknown, not invented.

No new MCP, graph database, daemon, or dashboard is required.

## Implementation sequence

### A. Collector

- [x] Inspect existing system-script packaging and applicable local instructions.
- [x] Define the research scope and evidence schema.
- [x] Implement bounded read-only collectors with explicit errors.
- [x] Test undeployed changes, failed probes, missing permissions, and agreeing state with fixtures.
- [x] Exercise the real NAS environment and retain its packet.

Retained packet: `c00dc4cf15dd4b409338e54861aa13bd`, collected on `nas` at
`2026-10-02T01:12:37.604212Z`, 24 observations, zero recorded probe errors,
CA checkout/pin `agree`; selected user-generation links and CA outcome reader
remain unknown. See the guide for JSON/Markdown paths. Refresh this evidence
for new work; it is not a standing claim about the live host.

### B. Salience pass

The skill and salience/contract validators/storage are implemented. The
unchecked items below are live judgment/acceptance work, not missing code.

- [ ] Ground direction in selected authored passages.
- [ ] Produce one evidence-backed possibility or an honest no-candidate result.
- [ ] Write its contract without executing beyond authority.
- [ ] Review ambiguous direction or consequential boundaries with the operator.

### C. First complete loop

The manual start/import-result/decide/followup lifecycle is implemented;
fixture success does not complete the following live steps.

- [ ] Preserve baseline, protected behavior, and counterexample.
- [ ] Run an authorized reversible experiment.
- [ ] Assess actual outputs against the contract.
- [ ] Record the decision and any justified reusable procedure.

### D. Transfer before scheduling

Transfer/surprise records and second-object fixtures are implemented. Real
transfer is pending; scheduling is optional deferred work, not an unbuilt
requirement for completing the manual loop.

- [ ] Exercise a second working object and assess appropriate transfer.
- [ ] Add optional scheduling only after manual usefulness is demonstrated.
- [ ] Allow no meaningful change as a legitimate result; never create obligations to fill a cadence.

## Acceptance criteria

1. Distinguishes working-tree changes from deployed configuration.
2. Distinguishes availability, completed work, and demonstrated usefulness.
3. Detects a real plan-versus-live-state discrepancy with evidence references.
4. Does not invent a discrepancy when sources agree.
5. Verifies proposed prerequisites and marks missing ones.
6. Refuses unsupported capability claims and retains collection failures.
7. Produces a contract linked to authored direction and computer evidence.
8. Preserves real experiment outputs and a decision without silently changing the ideal.
9. Demonstrates a regression/counterexample check.

A packet completes collection, not the learning loop. Acceptance of a proposal authorizes evaluation, not a claim of improvement.

## Ownership and activation

NixOS owns packaging, wiring, permissions, and reproducible arrangements. Authored knowledge owns direction. CA owns upstream identity compilation. Hermes owns bounded judgment and authorized action; existing coding-agent tooling can implement scoped changes. Langfuse remains the response-review surface, not a required sink for all computer facts.

The implemented consumption path is manual: Hermes reads relevant retained
JSON and their Markdown siblings, performs authorized work, presents the
result in the existing chat, and explicitly reloads prior records on resume.
`collect` and record-store commands write both formats under
`${XDG_STATE_HOME:-$HOME/.local/state}/research-state`; `render` accepts
packets only. The disabled CA reader is a future input adapter, not a missing
renderer. Nothing here watches that directory or automatically feeds results
to CA, Langfuse, a dashboard, QMD, SOUL, or memory. The guide describes a
concrete first experiment, later-use test, second-object transfer, and handoff.

Repository edits are not live until activated. The operator runs system/Home Manager activation. The agent does not rebuild, switch, or restart its gateway. Test package behavior and relevant Nix evaluation before activation handoff.

## Deferred

Whole-desktop capture; exhaustive resource enumeration; universal alignment scores; classifiers or weight training; silent system mutation; automatic dataset/SOUL promotion; new agent platforms; lifetime-memory frameworks; and dashboards before the first loop demonstrates value.

# CodyOS

CodyOS is a self-improving operating system built on top of NixOS.

The bet is that if a machine is declarative, legible, and reversible, AI can help shape it around the person using it.

That means the OS is not fixed. It can be edited, extended, and tuned over time based on what the person actually needs. When you get a new computer, just install it on the new one and you're up and running in a matter of minutes.

It is also a bet on owning the system instead of renting it. Instead of fitting yourself into a sandbox someone else designed, the machine can grow with you and keep adapting to the way you actually work.

Nix provides the safety properties for that: inspectable config, reproducible builds, and rollbacks. This repo adds the part Nix does not decide for you: agent tooling, local models, workflow harnesses, ergonomics, secrets, and automations.

## What that looks like right now

### Local model system

- Local models are served through `llama-swap` with supporting STT and TTS services around them.
- In practice, that powers things like press-to-talk transcription, spoken responses from Hermes and OpenCode, and local summarization of articles the user has marked as interesting.
- The same local model layer can be reused across tools instead of each workflow needing its own separate setup.

### Hermes as system infrastructure

- Hermes is configured as part of the OS, with runtime, memory, voice, MCP wiring, secrets, skills, and toolsets declared in Nix.
- That means agent capability is part of the machine definition, not a loose collection of tools someone has to reinstall and reconnect by hand.

### OpenCode as a reusable work surface

- OpenCode is wired with custom agents, skills, plugins, secret-backed MCP wrappers, and repo context.
- That lets useful workflows stick around. You do the wiring once, then the machine keeps offering the same capabilities the next time you need them.

### Personalization via Cognitive Assistant

- [Cognitive Assistant](https://github.com/Cody-W-Tucker/Cognitive-Assistant) is the personalization upstream for this repo. It generates user-specific artifacts like soul text, human profiles, skills, and alignment specs.
- This repo then wires those artifacts into Hermes and OpenCode so personalization does not stay trapped in prompts. It becomes part of the machine's actual agent behavior.
- The flow is: [Cognitive Assistant](https://github.com/Cody-W-Tucker/Cognitive-Assistant) describes the person, and CodyOS describes the machine. Together they produce a system that can be steered by personalized AI instead of a generic assistant living in a generic environment.
- Upstream artifacts are visible directly here:
  - [Existential human profile](https://github.com/Cody-W-Tucker/Cognitive-Assistant/blob/main/workspaces/existential/artifacts/human_profile.md)
  - [Operational human profile](https://github.com/Cody-W-Tucker/Cognitive-Assistant/blob/main/workspaces/operational/artifacts/human_profile.md)
  - [Generated existential skills](https://github.com/Cody-W-Tucker/Cognitive-Assistant/tree/main/workspaces/existential/artifacts/skills)
  - [Generated operational skills](https://github.com/Cody-W-Tucker/Cognitive-Assistant/tree/main/workspaces/operational/artifacts/skills)
  - [SOUL artifact](https://github.com/Cody-W-Tucker/Cognitive-Assistant/blob/main/workspaces/alignment/artifacts/SOUL.md)

### Hyprland ergonomics

- The desktop setup is also part of the idea. Hyprland, Waybar, and the session wiring are configured to reduce friction in day to day use.
- Direct login, workspace visibility, idle behavior, lock behavior, meeting links in the bar, and one-click access to common controls all matter because ergonomics are part of what makes a machine fit a person.
- This is one example of the broader point: optimization is not only about AI features. It is also about removing the little things that trip someone up all day.

### Automations that live with the machine

- Some workflows belong in the system, not in a checklist. The Miniflux curator is one example: it produces a curated feed by comparing new RSS items against the things the user has already saved and shown interest in.
- The larger idea is that repeated work should become infrastructure when possible.

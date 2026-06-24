# Hermes Skills

Owns packaged Hermes skills and the rules for exposing them to Hermes runtime state.

Does not own Hermes service wiring, MCP servers, package patches, or mutable skill edits under the state directory.

## Placement Rules

- Keep skills as normal files that can be copied into `${stateDir}/.hermes/skills`.
- Make each skill directory self-contained and named for the behavior it owns.
- Do not put service options, secrets, or runtime ACL changes here.
- Keep generated or experimental local skill state out of this packaged tree.
- If a skill needs a tool, expose the tool through the Hermes service/toolset layer, not from the skill file.

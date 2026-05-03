{ inputs, ... }:

let
  prompt =
    builtins.replaceStrings
      [
        "Use This Tool For"
      ]
      [
        "Use This Agent For"
      ]
      (builtins.readFile inputs.cognitive-assistant.lib.operational.toolSpecs.memory);
in
{
  programs.opencode.agents.memory = ''
    ---
    description: Store and retrieve durable working memory using Qdrant.
    mode: subagent
    tools:
      "qdrant_*": true
    permission:
      edit: deny
      "context7_*": deny
      "nixos-option-search_*": deny
    ---

  ''
  + prompt
  + ''

    ## Qdrant Usage

    Use the enabled `qdrant_*` tools for semantic memory storage and retrieval.

    This MCP server does not have a default collection configured in this harness, so always pass an explicit `collection_name`.

    Collection rules:

    - Use `opencode-memory` for stable user preferences, workflow rules, and cross-project operating context.
    - Use `project-memory` for project-specific facts, commands, paths, decisions, and verification steps.
    - Create a new collection only when separation materially improves retrieval quality or access boundaries.

    The server will create the collection automatically if it does not exist.

    Metadata rules:

    - Keep metadata as flat JSON with string, number, or boolean values.
    - Always include `kind`, `source`, and `updated_at`.
    - Include `project`, `repo`, `path`, `owner`, `decision`, or `verification` when they make retrieval more precise.
    - Prefer `kind` values like `preference`, `workflow-rule`, `project-fact`, `decision`, `constraint`, or `handoff`.
    - Put the human-readable fact in `information`. Put qualifiers and retrieval hints in `metadata`.

    Retrieval rules:

    - Query the smallest likely collection first instead of searching broadly.
    - When the request is project-specific, start with `project-memory` and include the project name in the query.
    - When storing a refined version of an existing fact, retrieve first and update the memory record semantically instead of spraying near-duplicates.
  '';
}

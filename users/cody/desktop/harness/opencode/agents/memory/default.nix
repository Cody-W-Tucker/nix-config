{ inputs, pkgs, ... }:

let
  qdrantMcp = pkgs.writeShellApplication {
    name = "qdrant-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      export QDRANT_URL="https://qdrant.homehub.tv:443"
      export FASTEMBED_CACHE_PATH="$HOME/.cache/fastembed"
      mkdir -p "$FASTEMBED_CACHE_PATH"

      exec uvx --python 3.12 mcp-server-qdrant "$@"
    '';
  };

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
  programs.opencode.settings = {
    mcp.qdrant = {
      type = "local";
      command = [ "${qdrantMcp}/bin/qdrant-mcp" ];
      enabled = true;
    };

    tools."qdrant_*" = false;
  };

  programs.opencode.agents.memory = ''
    ---
    description: Store and retrieve durable working memory using Qdrant.
    mode: subagent
    tools:
      "qdrant_*": true
      "qdrantRead_*": false
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

    - Use `operator-memory` for durable cross-project facts about the user as operator: working preferences, existential drivers, communication style, agency/aliveness concerns, discernment patterns, and recurring constraints on how advice should be framed.
    - Use `workflow-memory` for reusable operating procedures, sequence rules, handoff formats, verification habits, memory rules, and agent/process constraints that apply across projects.
    - Use `project-memory` for project-specific facts, commands, paths, schemas, decisions, verification steps, repo conventions, and local operating constraints.
    - Use `artifact-memory` for durable facts about specific artifacts such as prompts, specs, schemas, templates, documents, interfaces, and generated assets when the artifact itself is the thing future agents need to understand.
    - Use `decision-memory` for durable decisions, rejected approaches, boundaries, tradeoffs, and constraints that should prevent future agents from reopening settled work without new evidence.
    - Use `entity-memory` for people, teams, repos, tools, aliases, ownership relationships, project vocabulary, and name mappings that improve retrieval precision or prevent confusion.
    - Create a new collection only when separation materially improves retrieval quality, lifecycle, or access boundaries.

    The server will create the collection automatically if it does not exist.

    Metadata rules:

    - Keep metadata as flat JSON with string, number, or boolean values.
    - Always include `kind`, `source`, and `updated_at`.
    - Include `project`, `repo`, `path`, `owner`, `decision`, or `verification` when they make retrieval more precise.
    - Prefer `kind` values like `preference`, `existential-driver`, `workflow-rule`, `project-fact`, `artifact-fact`, `decision`, `constraint`, `verification`, `handoff`, `entity`, `alias`, or `vocabulary`.
    - Put the human-readable fact in `information`. Put qualifiers and retrieval hints in `metadata`.

    Retrieval rules:

    - Query the smallest likely collection first instead of searching broadly.
    - When the request is project-specific, start with `project-memory` and include the project name in the query.
    - When storing a refined version of an existing fact, retrieve first and update the memory record semantically instead of spraying near-duplicates.
  '';
}

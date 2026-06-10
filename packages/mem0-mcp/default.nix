{
  writeShellApplication,
  python313,
  enCoreWebSm,
  mem0ai,
}:

let
  pythonEnv = python313.withPackages (ps: [
    enCoreWebSm
    ps.fastembed
    mem0ai
    ps.spacy
    ps.fastmcp
    ps.pydantic
  ]);
in
writeShellApplication {
  name = "mem0-mcp";
  runtimeInputs = [ pythonEnv ];
  text = ''
    export MEM0_TELEMETRY=''${MEM0_TELEMETRY:-false}
    export ANONYMIZED_TELEMETRY=''${ANONYMIZED_TELEMETRY:-false}
    export MEM0_DATA_DIR=''${MEM0_DATA_DIR:-/var/lib/mem0}
    export MEM0_HISTORY_DB_PATH=''${MEM0_HISTORY_DB_PATH:-$MEM0_DATA_DIR/history.db}
    export MEM0_DEFAULT_USER_ID=''${MEM0_DEFAULT_USER_ID:-codyt}
    export MEM0_COLLECTION_NAME=''${MEM0_COLLECTION_NAME:-shared-agent-memory}
    export MEM0_LLM_PROVIDER=''${MEM0_LLM_PROVIDER:-openai}
    export MEM0_LLM_MODEL=''${MEM0_LLM_MODEL:-qwen3.5-0.8b}
    export MEM0_EMBEDDER_PROVIDER=''${MEM0_EMBEDDER_PROVIDER:-openai}
    export MEM0_EMBEDDER_MODEL=''${MEM0_EMBEDDER_MODEL:-qwen3-embedding-0.6b}
    export MEM0_OPENAI_BASE_URL=''${MEM0_OPENAI_BASE_URL:-http://127.0.0.1:8081/v1}
    export OPENAI_BASE_URL=''${OPENAI_BASE_URL:-$MEM0_OPENAI_BASE_URL}
    export OPENAI_API_KEY=''${OPENAI_API_KEY:-local-only}
    export MEM0_QDRANT_HOST=''${MEM0_QDRANT_HOST:-127.0.0.1}
    export MEM0_QDRANT_PORT=''${MEM0_QDRANT_PORT:-6333}

    umask 0007
    mkdir -p "$MEM0_DATA_DIR"

    # OpenCode and Hermes share this SQLite DB via a common group, so keep the
    # main file group-writable no matter which side creates it first.
    touch "$MEM0_HISTORY_DB_PATH"
    chmod 0660 "$MEM0_HISTORY_DB_PATH" 2>/dev/null || true

    for sidecar in "$MEM0_HISTORY_DB_PATH-wal" "$MEM0_HISTORY_DB_PATH-shm"; do
      if [ -e "$sidecar" ]; then
        chmod 0660 "$sidecar" 2>/dev/null || true
      fi
    done

    exec ${pythonEnv}/bin/python ${./server.py} "$@"
  '';
}

{
  writeShellApplication,
  python313,
  mem0ai,
}:

let
  pythonEnv = python313.withPackages (ps: [
    mem0ai
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
    export MEM0_LLM_MODEL=''${MEM0_LLM_MODEL:-qwen3.5-4b}
    export MEM0_EMBEDDER_PROVIDER=''${MEM0_EMBEDDER_PROVIDER:-openai}
    export MEM0_EMBEDDER_MODEL=''${MEM0_EMBEDDER_MODEL:-qwen3-embedding-0.6b}
    export MEM0_OPENAI_BASE_URL=''${MEM0_OPENAI_BASE_URL:-http://127.0.0.1:8081/v1}
    export OPENAI_BASE_URL=''${OPENAI_BASE_URL:-$MEM0_OPENAI_BASE_URL}
    export OPENAI_API_KEY=''${OPENAI_API_KEY:-local-only}
    export MEM0_QDRANT_HOST=''${MEM0_QDRANT_HOST:-127.0.0.1}
    export MEM0_QDRANT_PORT=''${MEM0_QDRANT_PORT:-6333}

    umask 0007
    mkdir -p "$MEM0_DATA_DIR"

    exec ${pythonEnv}/bin/python ${./server.py} "$@"
  '';
}

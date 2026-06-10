#!/usr/bin/env python3
import json
import os
from typing import Optional

from fastmcp import FastMCP
from mem0 import Memory
from pydantic import Field


def get_embedding_dims() -> int:
    dims = {
        "qwen3-embedding-0.6b": 1024,
        "text-embedding-3-small": 1536,
        "text-embedding-3-large": 3072,
    }
    return dims.get(os.environ.get("MEM0_EMBEDDER_MODEL", "").lower(), 1024)


def build_provider_config(provider: str, model: str) -> dict:
    config = {"model": model}

    if provider == "openai":
        config["api_key"] = os.environ.get("OPENAI_API_KEY", "local-only")
        config["openai_base_url"] = os.environ.get(
            "MEM0_OPENAI_BASE_URL", os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8081/v1")
        )

    return config


def build_config() -> dict:
    llm_provider = os.environ.get("MEM0_LLM_PROVIDER", "openai")
    llm_model = os.environ.get("MEM0_LLM_MODEL", "qwen3.5-4b")
    embedder_provider = os.environ.get("MEM0_EMBEDDER_PROVIDER", "openai")
    embedder_model = os.environ.get("MEM0_EMBEDDER_MODEL", "qwen3-embedding-0.6b")

    return {
        "version": "v1.1",
        "history_db_path": os.environ.get("MEM0_HISTORY_DB_PATH", "/var/lib/mem0/history.db"),
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "host": os.environ.get("MEM0_QDRANT_HOST", "127.0.0.1"),
                "port": int(os.environ.get("MEM0_QDRANT_PORT", "6333")),
                "collection_name": os.environ.get("MEM0_COLLECTION_NAME", "shared-agent-memory"),
                "embedding_model_dims": get_embedding_dims(),
            },
        },
        "llm": {
            "provider": llm_provider,
            "config": build_provider_config(llm_provider, llm_model) | {"temperature": 0},
        },
        "embedder": {
            "provider": embedder_provider,
            "config": build_provider_config(embedder_provider, embedder_model)
            | {"embedding_dims": get_embedding_dims()},
        },
    }


memory = Memory.from_config(build_config())
mcp = FastMCP("mem0")


def parse_metadata(metadata: Optional[str]) -> Optional[dict]:
    if not metadata:
        return None
    return json.loads(metadata)


@mcp.tool()
def add_memory(
    content: str = Field(description="Content to store as durable memory"),
    user_id: Optional[str] = Field(default=None, description="Optional user ID override"),
    agent_id: Optional[str] = Field(default=None, description="Optional agent ID scope"),
    metadata: Optional[str] = Field(default=None, description="Optional JSON metadata object"),
) -> str:
    result = memory.add(
        [{"role": "user", "content": content}],
        user_id=user_id or os.environ.get("MEM0_DEFAULT_USER_ID", "codyt"),
        agent_id=agent_id,
        metadata=parse_metadata(metadata),
    )
    return json.dumps(result, indent=2)


@mcp.tool()
def search_memories(
    query: str = Field(description="Search query"),
    user_id: Optional[str] = Field(default=None, description="Optional user ID override"),
    agent_id: Optional[str] = Field(default=None, description="Optional agent ID scope"),
    limit: int = Field(default=10, description="Maximum results to return"),
) -> str:
    result = memory.search(
        query=query,
        user_id=user_id or os.environ.get("MEM0_DEFAULT_USER_ID", "codyt"),
        agent_id=agent_id,
        limit=limit,
    )
    return json.dumps(result, indent=2)


@mcp.tool()
def get_all_memories(
    user_id: Optional[str] = Field(default=None, description="Optional user ID override"),
    agent_id: Optional[str] = Field(default=None, description="Optional agent ID scope"),
) -> str:
    result = memory.get_all(
        user_id=user_id or os.environ.get("MEM0_DEFAULT_USER_ID", "codyt"),
        agent_id=agent_id,
    )
    return json.dumps(result, indent=2)


@mcp.tool()
def get_memory(memory_id: str = Field(description="Memory ID to retrieve")) -> str:
    return json.dumps(memory.get(memory_id), indent=2)


@mcp.tool()
def update_memory(
    memory_id: str = Field(description="Memory ID to update"),
    content: str = Field(description="Replacement content"),
) -> str:
    return json.dumps(memory.update(memory_id, content), indent=2)


@mcp.tool()
def delete_memory(memory_id: str = Field(description="Memory ID to delete")) -> str:
    memory.delete(memory_id)
    return json.dumps({"status": "deleted", "memory_id": memory_id}, indent=2)


@mcp.tool()
def delete_all_memories(
    user_id: Optional[str] = Field(default=None, description="Optional user ID override"),
    agent_id: Optional[str] = Field(default=None, description="Optional agent ID scope"),
) -> str:
    memory.delete_all(
        user_id=user_id or os.environ.get("MEM0_DEFAULT_USER_ID", "codyt"),
        agent_id=agent_id,
    )
    return json.dumps(
        {
            "status": "deleted_all",
            "user_id": user_id or os.environ.get("MEM0_DEFAULT_USER_ID", "codyt"),
            "agent_id": agent_id,
        },
        indent=2,
    )


@mcp.tool()
def get_memory_history(memory_id: str = Field(description="Memory ID to inspect")) -> str:
    return json.dumps(memory.history(memory_id), indent=2)


if __name__ == "__main__":
    mcp.run()

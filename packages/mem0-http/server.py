#!/usr/bin/env python3
import os
from typing import Any

from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from mem0 import Memory


def get_embedding_dims() -> int:
    dims = {
        "qwen3-embedding-0.6b": 1024,
        "text-embedding-3-small": 1536,
        "text-embedding-3-large": 3072,
    }
    return dims.get(os.environ.get("MEM0_EMBEDDER_MODEL", "").lower(), 1024)


def build_provider_config(provider: str, model: str) -> dict[str, Any]:
    config: dict[str, Any] = {"model": model}

    if provider == "openai":
        config["api_key"] = os.environ.get("OPENAI_API_KEY", "local-only")
        config["openai_base_url"] = os.environ.get(
            "MEM0_OPENAI_BASE_URL", os.environ.get("OPENAI_BASE_URL", "http://127.0.0.1:8081/v1")
        )

    return config


def build_config() -> dict[str, Any]:
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


def normalize_filters(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    payload = payload or {}
    filters = dict(payload.get("filters") or {})

    for key in ("user_id", "agent_id", "run_id"):
        value = payload.get(key)
        if value and key not in filters:
            filters[key] = value

    return filters


def require_entity_scope(filters: dict[str, Any]) -> None:
    if not any(filters.get(key) for key in ("user_id", "agent_id", "run_id")):
        raise HTTPException(status_code=400, detail="filters must include user_id, agent_id, or run_id")


memory = Memory.from_config(build_config())
app = FastAPI(title="mem0-http", version="0.1.0")


@app.middleware("http")
async def require_token(request: Request, call_next):
    expected = os.environ.get("MEM0_HTTP_API_KEY", "local-only")
    auth = request.headers.get("authorization", "")

    if expected:
        token = f"Token {expected}"
        if auth != token:
            return JSONResponse(status_code=401, content={"detail": "Invalid API key"})

    return await call_next(request)


@app.get("/v1/ping/")
def ping(mem0_user_id: str | None = Header(default=None, alias="Mem0-User-ID")) -> dict[str, Any]:
    return {
        "message": "pong",
        "org_id": "local",
        "project_id": "oss",
        "user_email": mem0_user_id or "local@mem0",
    }


@app.post("/v3/memories/add/")
async def add_memory(payload: dict[str, Any]) -> dict[str, Any]:
    messages = payload.get("messages")
    if messages is None:
        raise HTTPException(status_code=400, detail="messages is required")

    filters = normalize_filters(payload)
    require_entity_scope(filters)

    return memory.add(
        messages,
        user_id=filters.get("user_id"),
        agent_id=filters.get("agent_id"),
        run_id=filters.get("run_id"),
        metadata=payload.get("metadata"),
        infer=payload.get("infer", True),
        memory_type=payload.get("memory_type"),
        prompt=payload.get("custom_instructions"),
    )


@app.post("/v3/memories/")
async def get_all_memories(payload: dict[str, Any]) -> dict[str, Any]:
    filters = normalize_filters(payload)
    require_entity_scope(filters)

    page_size = payload.get("page_size")
    top_k = int(page_size) if page_size is not None else 100
    result = memory.get_all(filters=filters, top_k=top_k)
    results = result.get("results", [])

    return {
        "count": len(results),
        "next": None,
        "previous": None,
        "results": results,
    }


@app.post("/v3/memories/search/")
async def search_memories(payload: dict[str, Any]) -> dict[str, Any]:
    query = payload.get("query")
    if not query:
        raise HTTPException(status_code=400, detail="query is required")

    filters = normalize_filters(payload)
    require_entity_scope(filters)

    return memory.search(
        query=query,
        filters=filters,
        top_k=int(payload.get("top_k", 10)),
        rerank=bool(payload.get("rerank", False)),
        threshold=float(payload.get("threshold", 0.1)),
    )


@app.get("/v1/memories/{memory_id}/")
async def get_memory(memory_id: str) -> dict[str, Any]:
    result = memory.get(memory_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Memory with id {memory_id} not found")
    return result


@app.put("/v1/memories/{memory_id}/")
async def update_memory(memory_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    text = payload.get("text")
    if not text:
        raise HTTPException(status_code=400, detail="text is required")

    metadata = dict(payload.get("metadata") or {})
    timestamp = payload.get("timestamp")
    if timestamp is not None:
        metadata["updated_at"] = str(timestamp)

    return memory.update(memory_id, text, metadata=metadata or None)


@app.delete("/v1/memories/{memory_id}/")
async def delete_memory(memory_id: str) -> dict[str, Any]:
    return memory.delete(memory_id)


@app.delete("/v1/memories/")
async def delete_all_memories(
    user_id: str | None = Query(default=None),
    agent_id: str | None = Query(default=None),
    run_id: str | None = Query(default=None),
) -> dict[str, Any]:
    if not any([user_id, agent_id, run_id]):
        raise HTTPException(status_code=400, detail="user_id, agent_id, or run_id is required")

    return memory.delete_all(user_id=user_id, agent_id=agent_id, run_id=run_id)


@app.get("/v1/memories/{memory_id}/history/")
async def get_memory_history(memory_id: str) -> list[dict[str, Any]]:
    return memory.history(memory_id)

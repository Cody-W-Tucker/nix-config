"""Local Mem0 memory provider backed by the in-house OSS Mem0 HTTP shim."""

from __future__ import annotations

import json
import logging
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, List

from agent.memory_provider import MemoryProvider
from tools.registry import tool_error

logger = logging.getLogger(__name__)

_BREAKER_THRESHOLD = 5
_BREAKER_COOLDOWN_SECS = 120


def _load_config() -> dict:
    from hermes_constants import get_hermes_home

    config = {
        "api_key": os.environ.get("MEM0_API_KEY", ""),
        "host": os.environ.get("MEM0_HOST", "http://127.0.0.1:8765"),
        "user_id": os.environ.get("MEM0_USER_ID", "hermes-user"),
        "agent_id": os.environ.get("MEM0_AGENT_ID", "hermes"),
        "rerank": True,
    }

    config_path = get_hermes_home() / "mem0-local.json"
    if config_path.exists():
        try:
            file_cfg = json.loads(config_path.read_text(encoding="utf-8"))
            config.update({k: v for k, v in file_cfg.items() if v is not None and v != ""})
        except Exception:
            pass

    return config


PROFILE_SCHEMA = {
    "name": "mem0_profile",
    "description": "Retrieve all stored shared memories about the user.",
    "parameters": {"type": "object", "properties": {}, "required": []},
}

SEARCH_SCHEMA = {
    "name": "mem0_search",
    "description": "Search shared memories by semantic meaning.",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "What to search for."},
            "rerank": {"type": "boolean", "description": "Enable reranking for precision."},
            "top_k": {"type": "integer", "description": "Max results (default: 10, max: 50)."},
        },
        "required": ["query"],
    },
}

CONCLUDE_SCHEMA = {
    "name": "mem0_conclude",
    "description": "Store a durable shared fact verbatim.",
    "parameters": {
        "type": "object",
        "properties": {
            "conclusion": {"type": "string", "description": "The fact to store."},
        },
        "required": ["conclusion"],
    },
}


class Mem0LocalMemoryProvider(MemoryProvider):
    def __init__(self):
        self._config = None
        self._api_key = ""
        self._host = "http://127.0.0.1:8765"
        self._user_id = "hermes-user"
        self._agent_id = "hermes"
        self._rerank = True
        self._prefetch_result = ""
        self._prefetch_lock = threading.Lock()
        self._prefetch_thread = None
        self._sync_thread = None
        self._consecutive_failures = 0
        self._breaker_open_until = 0.0

    @property
    def name(self) -> str:
        return "mem0-local"

    def is_available(self) -> bool:
        cfg = _load_config()
        return bool(cfg.get("api_key")) and bool(cfg.get("host"))

    def save_config(self, values, hermes_home):
        from pathlib import Path
        from utils import atomic_json_write

        config_path = Path(hermes_home) / "mem0-local.json"
        existing = {}
        if config_path.exists():
            try:
                existing = json.loads(config_path.read_text())
            except Exception:
                pass
        existing.update(values)
        atomic_json_write(config_path, existing, mode=0o600)

    def get_config_schema(self):
        return [
            {"key": "api_key", "description": "Local Mem0 API key", "secret": True, "required": True, "env_var": "MEM0_API_KEY"},
            {"key": "host", "description": "Local Mem0 host", "default": "http://127.0.0.1:8765"},
            {"key": "user_id", "description": "User identifier", "default": "hermes-user"},
            {"key": "agent_id", "description": "Agent identifier", "default": "hermes"},
            {"key": "rerank", "description": "Enable reranking for recall", "default": "true", "choices": ["true", "false"]},
        ]

    def _request(self, method: str, path: str, *, payload: dict | None = None, query: dict | None = None) -> Any:
        url = f"{self._host.rstrip('/')}{path}"
        if query:
            query_string = urllib.parse.urlencode({k: v for k, v in query.items() if v is not None})
            if query_string:
                url = f"{url}?{query_string}"

        data = None
        headers = {
            "Authorization": f"Token {self._api_key}",
            "Content-Type": "application/json",
        }
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")

        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8")
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{e.code} {e.reason}: {body}") from e
        except urllib.error.URLError as e:
            raise RuntimeError(f"Connection failed: {e.reason}") from e

    def _is_breaker_open(self) -> bool:
        if self._consecutive_failures < _BREAKER_THRESHOLD:
            return False
        if time.monotonic() >= self._breaker_open_until:
            self._consecutive_failures = 0
            return False
        return True

    def _record_success(self):
        self._consecutive_failures = 0

    def _record_failure(self):
        self._consecutive_failures += 1
        if self._consecutive_failures >= _BREAKER_THRESHOLD:
            self._breaker_open_until = time.monotonic() + _BREAKER_COOLDOWN_SECS
            logger.warning(
                "Mem0-local circuit breaker tripped after %d consecutive failures. Pausing API calls for %ds.",
                self._consecutive_failures,
                _BREAKER_COOLDOWN_SECS,
            )

    def initialize(self, session_id: str, **kwargs) -> None:
        self._config = _load_config()
        self._api_key = self._config.get("api_key", "")
        self._host = self._config.get("host", "http://127.0.0.1:8765")
        self._user_id = kwargs.get("user_id") or self._config.get("user_id", "hermes-user")
        self._agent_id = self._config.get("agent_id", "hermes")
        self._rerank = self._config.get("rerank", True)

    def _read_filters(self) -> Dict[str, Any]:
        return {"user_id": self._user_id}

    def _write_filters(self) -> Dict[str, Any]:
        return {"user_id": self._user_id, "agent_id": self._agent_id}

    @staticmethod
    def _unwrap_results(response: Any) -> list:
        if isinstance(response, dict):
            return response.get("results", [])
        if isinstance(response, list):
            return response
        return []

    def system_prompt_block(self) -> str:
        return (
            "# Mem0 Local Memory\n"
            f"Active. Host: {self._host}. User: {self._user_id}.\n"
            "Use mem0_search to find shared memories, mem0_conclude to store facts, "
            "mem0_profile for a full overview."
        )

    def prefetch(self, query: str, *, session_id: str = "") -> str:
        if self._prefetch_thread and self._prefetch_thread.is_alive():
            self._prefetch_thread.join(timeout=3.0)
        with self._prefetch_lock:
            result = self._prefetch_result
            self._prefetch_result = ""
        if not result:
            return ""
        return f"## Mem0 Memory\n{result}"

    def queue_prefetch(self, query: str, *, session_id: str = "") -> None:
        if self._is_breaker_open():
            return

        def _run():
            try:
                results = self._unwrap_results(
                    self._request(
                        "POST",
                        "/v3/memories/search/",
                        payload={
                            "query": query,
                            "filters": self._read_filters(),
                            "rerank": self._rerank,
                            "top_k": 5,
                        },
                    )
                )
                if results:
                    lines = [r.get("memory", "") for r in results if r.get("memory")]
                    with self._prefetch_lock:
                        self._prefetch_result = "\n".join(f"- {line}" for line in lines)
                self._record_success()
            except Exception as e:
                self._record_failure()
                logger.debug("Mem0-local prefetch failed: %s", e)

        self._prefetch_thread = threading.Thread(target=_run, daemon=True, name="mem0-local-prefetch")
        self._prefetch_thread.start()

    def sync_turn(self, user_content: str, assistant_content: str, *, session_id: str = "") -> None:
        if self._is_breaker_open():
            return

        def _sync():
            try:
                self._request(
                    "POST",
                    "/v3/memories/add/",
                    payload={
                        "messages": [
                            {"role": "user", "content": user_content},
                            {"role": "assistant", "content": assistant_content},
                        ],
                        **self._write_filters(),
                    },
                )
                self._record_success()
            except Exception as e:
                self._record_failure()
                logger.warning("Mem0-local sync failed: %s", e)

        if self._sync_thread and self._sync_thread.is_alive():
            self._sync_thread.join(timeout=5.0)

        self._sync_thread = threading.Thread(target=_sync, daemon=True, name="mem0-local-sync")
        self._sync_thread.start()

    def get_tool_schemas(self) -> List[Dict[str, Any]]:
        return [PROFILE_SCHEMA, SEARCH_SCHEMA, CONCLUDE_SCHEMA]

    def handle_tool_call(self, tool_name: str, args: dict, **kwargs) -> str:
        if self._is_breaker_open():
            return json.dumps({"error": "Mem0-local API temporarily unavailable. Will retry automatically."})

        if tool_name == "mem0_profile":
            try:
                memories = self._unwrap_results(
                    self._request(
                        "POST",
                        "/v3/memories/",
                        payload={"filters": self._read_filters()},
                    )
                )
                self._record_success()
                if not memories:
                    return json.dumps({"result": "No memories stored yet."})
                lines = [m.get("memory", "") for m in memories if m.get("memory")]
                return json.dumps({"result": "\n".join(lines), "count": len(lines)})
            except Exception as e:
                self._record_failure()
                return tool_error(f"Failed to fetch profile: {e}")

        if tool_name == "mem0_search":
            query = args.get("query", "")
            if not query:
                return tool_error("Missing required parameter: query")
            rerank = args.get("rerank", False)
            top_k = min(int(args.get("top_k", 10)), 50)
            try:
                results = self._unwrap_results(
                    self._request(
                        "POST",
                        "/v3/memories/search/",
                        payload={
                            "query": query,
                            "filters": self._read_filters(),
                            "rerank": rerank,
                            "top_k": top_k,
                        },
                    )
                )
                self._record_success()
                if not results:
                    return json.dumps({"result": "No relevant memories found."})
                items = [{"memory": r.get("memory", ""), "score": r.get("score", 0)} for r in results]
                return json.dumps({"results": items, "count": len(items)})
            except Exception as e:
                self._record_failure()
                return tool_error(f"Search failed: {e}")

        if tool_name == "mem0_conclude":
            conclusion = args.get("conclusion", "")
            if not conclusion:
                return tool_error("Missing required parameter: conclusion")
            try:
                self._request(
                    "POST",
                    "/v3/memories/add/",
                    payload={
                        "messages": [{"role": "user", "content": conclusion}],
                        "infer": False,
                        **self._write_filters(),
                    },
                )
                self._record_success()
                return json.dumps({"result": "Fact stored."})
            except Exception as e:
                self._record_failure()
                return tool_error(f"Failed to store: {e}")

        return tool_error(f"Unknown tool: {tool_name}")

    def shutdown(self) -> None:
        for thread in (self._prefetch_thread, self._sync_thread):
            if thread and thread.is_alive():
                thread.join(timeout=5.0)


def register(ctx) -> None:
    ctx.register_memory_provider(Mem0LocalMemoryProvider())

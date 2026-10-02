#!/usr/bin/env python3
"""research-state: bounded research-continuity collector plus salience/contract/attempt
judgment records with second-object transfer and surprise handoff (Slices A+B+C+D).

Joins Git checkouts/pins, selected note citations, deployment evidence, named
services, interfaces/outcomes, XDG state, CLI overrides and immutable packets.

Subcommands:
  collect --scope FILE --state-dir DIR [--nixos-repo PATH --ca-repo PATH
      --personal-root PATH --wiki-root PATH]
  render PACKET [--format markdown|text]
  validate PACKET
  salience-validate RECORD [--packet PACKET]
  salience-store RECORD --state-dir DIR [--packet PACKET]
  contract-validate CONTRACT [--packet PACKET]
  contract-store CONTRACT --state-dir DIR [--packet PACKET]
  attempt-validate RECORD [--expect-stage STAGE --packet PACKET
      --contract CONTRACT --prior PRIOR --artifact-root DIR]
  attempt-start RECORD --state-dir DIR [--packet PACKET --contract CONTRACT]
  attempt-import-result RECORD --state-dir DIR [--packet PACKET
      --after-packet PACKET --contract CONTRACT --prior PRIOR
      --artifact-root DIR]
  attempt-decide RECORD --state-dir DIR [--packet PACKET
      --after-packet PACKET --prior PRIOR]
  attempt-followup RECORD --state-dir DIR [--packet PACKET
      --after-packet PACKET --fresh-packet PACKET --prior PRIOR]
  transfer-validate RECORD [--packet TARGET_PACKET --prior SOURCE_ATTEMPT]
  transfer-store RECORD --state-dir DIR --packet TARGET_PACKET
      --prior SOURCE_ATTEMPT
  surprise-validate RECORD [--packet PACKET]
  surprise-store RECORD --state-dir DIR --packet PACKET

  Slice D adds no timer, cron, scheduler module, dashboard, daemon, or
  background collection. Scheduling is deliberately absent until manual
  usefulness is shown.

Design constraints:
  - Python stdlib only.
  - Deterministic data gathering, not salience judgment.
  - Fixed bounded adapters; subprocess calls never use shell and never execute
    command strings from scope. Only fixed argv (git/systemctl/qmd) with
    scope-supplied paths as operands.
  - Every probe has a timeout and byte cap; failures are recorded as explicit
    errors/unknown observations, never raised, never invented.
  - Private + immutable output: state dir 0700, packets 0600, unique
    timestamped names, atomic writes, never overwritten.
  - No credentials, environment values, process arguments, message dumps,
    diff bodies, remote URLs, or service Environment/ExecStart.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

SCHEMA = "research-state/v1"
SCOPE_SCHEMA = "research-state-scope/v1"

# Slice B: Hermes judgment records. Collection stays deterministic; these
# schemas carry interpretation. Shape validation never authorizes execution.
SALIENCE_SCHEMA = "research-salience/v1"
CONTRACT_SCHEMA = "research-contract/v1"

# Slice C: manual attempt lifecycle. The collector never executes experiment
# commands: acceptance-check `command` strings inside attempt records are
# recorded data, never run. Hermes/operator runs an authorized experiment
# outside this tool, then supplies bounded real evidence with provenance.
ATTEMPT_SCHEMA = "research-attempt/v1"
ATTEMPT_STAGES = ("started", "result", "decided", "followed_up")
ATTEMPT_DECISIONS = ("keep", "revise", "discard", "inconclusive")
CHECK_STATUSES = ("pass", "fail", "unknown", "review_required")
BASELINE_STATUSES = ("pass", "fail", "unknown")
AUTHORITY_STATUSES = (
    "hermes_proposed",
    "operator_approved",
    "manual_review_pending",
)
ATTEMPT_ARTIFACT_MEDIA = ("text", "markdown", "json", "jsonl", "log")
ATTEMPT_MAX_ARTIFACTS = 8
ATTEMPT_MAX_ARTIFACT_BYTES = 16384
ATTEMPT_ARTIFACT_SUFFIXES = (".txt", ".md", ".json", ".jsonl", ".log")

SALIENCE_STATUSES = ("candidate", "no_candidate", "insufficient_evidence")
EXPERIMENT_TYPES = ("capability", "discovery")
PREREQ_STATUSES = ("verified", "missing", "unknown")

# Slice D: bounded second-working-object transfer plus an optional useful
# surprise operator handoff. Transfer reuses the same scope/packet/contract/
# attempt interfaces against an explicit alternate scope: no hardcoded first-
# object names, no graph/mission-space engine, no surprise score, and no
# schedule/timer/daemon. A surprise handoff is recognized/rejected/unknown by
# the operator only; absence of complaint never counts as recognition.
TRANSFER_SCHEMA = "research-transfer/v1"
SURPRISE_SCHEMA = "research-surprise/v1"
TRANSFER_STATUSES = ("adapted", "declined", "insufficient_evidence", "no_change")
SURPRISE_OPERATOR_STATUSES = ("recognized", "rejected", "unknown")
LATER_CONTACT_STATUSES = ("pending", "confirmed", "contradicted")
CHECK_KINDS = ("executable", "human_review")
CAPABILITY_CLAIMS = ("supported", "unsupported")
MAX_CANDIDATES = 3

LAYERS = ("declared", "deployed", "verified_available", "unavailable", "unknown")
COMPARISON_STATUSES = ("agree", "different", "unknown")

DEFAULT_PERSONAL_ROOT = "/home/codyt/Knowledge/Personal"
DEFAULT_WIKI_ROOT = "/home/codyt/Knowledge/wiki"
DEFAULT_CA_ROOT = "/home/codyt/Projects/Cognitive-Assistant"
DEFAULT_NIXOS_ROOT = "/etc/nixos"

# Allowlisted `systemctl show` properties only. Never Environment/ExecStart,
# journal dumps, env dumps or ps args.
SERVICE_PROPERTIES = [
    "Id",
    "LoadState",
    "ActiveState",
    "SubState",
    "Result",
    "ExecMainStatus",
    "ActiveEnterTimestamp",
    "NextElapseUSecRealtime",
    "LastTriggerUSec",
]

# Allowlisted outcome-file metadata fields only (known-schema projections).
OUTCOME_FIELDS = frozenset(
    {
        "schema",
        "id",
        "decision",
        "decided_at",
        "recorded_at",
        "packet_id",
        "evidence",
        "count",
        "status",
    }
)

FRONTMATTER_DATE_RE = re.compile(
    r"^(date|created|updated|modified)\s*:\s*(.+?)\s*$",
    re.IGNORECASE,
)

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")


def _default_scope_path() -> Path:
    return Path(__file__).with_name("scope.json")


def _default_state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(
        os.path.expanduser("~"), ".local", "state"
    )
    return Path(base) / "research-state"


def utc_now_iso(now_fn=None) -> str:
    """Current UTC time as ISO-8601 Z string. Injectable clock for tests."""
    if now_fn is not None:
        now = now_fn()
        if isinstance(now, datetime.datetime):
            if now.tzinfo is None:
                now = now.replace(tzinfo=datetime.timezone.utc)
            return now.astimezone(datetime.timezone.utc).isoformat().replace(
                "+00:00", "Z"
            )
        return str(now)
    return (
        datetime.datetime.now(datetime.timezone.utc)
        .isoformat()
        .replace("+00:00", "Z")
    )


def _fail(message: str) -> ValueError:
    return ValueError(message)


def _require_str(obj: dict, key: str, where: str) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value:
        raise _fail(f"{where}: missing non-empty string {key!r}")
    return value


def load_scope(scope_path: str | os.PathLike | None) -> dict:
    """Load and strictly validate a scope document (fail-fast)."""
    path = Path(scope_path) if scope_path is not None else _default_scope_path()
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise _fail(f"cannot read scope file {path}: {exc.strerror or exc}") from exc
    try:
        scope = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise _fail(f"scope file {path} is not valid JSON: {exc}") from exc
    if not isinstance(scope, dict):
        raise _fail(f"scope file {path}: top level must be an object")
    if scope.get("schema") != SCOPE_SCHEMA:
        raise _fail(
            f"scope file {path}: expected schema {SCOPE_SCHEMA!r}, "
            f"got {scope.get('schema')!r}"
        )
    working = scope.get("working_object")
    if not isinstance(working, dict):
        raise _fail(f"scope file {path}: 'working_object' must be an object")
    _require_str(working, "id", "scope working_object")
    _require_str(working, "description", "scope working_object")

    repos = scope.get("repositories")
    if not isinstance(repos, list) or not repos:
        raise _fail(f"scope file {path}: 'repositories' must be a non-empty list")
    seen_repos: set[str] = set()
    for repo in repos:
        if not isinstance(repo, dict):
            raise _fail(f"scope file {path}: each repository must be an object")
        rid = _require_str(repo, "id", "scope repository")
        _require_str(repo, "path", "scope repository")
        if not ID_RE.match(rid):
            raise _fail(f"scope file {path}: repository id {rid!r} is not a safe identifier")
        if rid in seen_repos:
            raise _fail(f"scope file {path}: duplicate repository id {rid!r}")
        seen_repos.add(rid)

    pins = scope.get("pins")
    if not isinstance(pins, dict):
        raise _fail(f"scope file {path}: 'pins' must be an object")
    _require_str(pins, "repository", "scope pins")
    _require_str(pins, "file", "scope pins")
    if pins["repository"] not in seen_repos:
        raise _fail(
            f"scope file {path}: pins.repository {pins['repository']!r} "
            f"names no configured repository"
        )
    inputs = pins.get("inputs")
    if not isinstance(inputs, list) or not inputs or not all(
        isinstance(i, str) and i for i in inputs
    ):
        raise _fail(f"scope file {path}: pins.inputs must be a non-empty string list")
    comparisons = pins.get("comparisons")
    if not isinstance(comparisons, list):
        raise _fail(f"scope file {path}: pins.comparisons must be a list")
    for comp in comparisons:
        if not isinstance(comp, dict):
            raise _fail(f"scope file {path}: each pins comparison must be an object")
        _require_str(comp, "input", "scope pins comparison")
        _require_str(comp, "repository", "scope pins comparison")
        if comp["input"] not in inputs:
            raise _fail(
                f"scope file {path}: comparison input {comp['input']!r} "
                f"not in pins.inputs"
            )
        if comp["repository"] not in seen_repos:
            raise _fail(
                f"scope file {path}: comparison repository {comp['repository']!r} "
                f"names no configured repository"
            )

    deployment = scope.get("deployment")
    if not isinstance(deployment, dict):
        raise _fail(f"scope file {path}: 'deployment' must be an object")
    _require_str(deployment, "system", "scope deployment")
    user_candidates = deployment.get("user_candidates")
    if not isinstance(user_candidates, list) or not all(
        isinstance(c, str) and c for c in user_candidates
    ):
        raise _fail(
            f"scope file {path}: deployment.user_candidates must be a string list"
        )

    notes = scope.get("notes")
    if not isinstance(notes, list) or not notes:
        raise _fail(f"scope file {path}: 'notes' must be a non-empty list")
    seen_notes: set[str] = set()
    for note in notes:
        if not isinstance(note, dict):
            raise _fail(f"scope file {path}: each note must be an object")
        nid = _require_str(note, "id", "scope note")
        if not ID_RE.match(nid):
            raise _fail(f"scope file {path}: note id {nid!r} is not a safe identifier")
        if nid in seen_notes:
            raise _fail(f"scope file {path}: duplicate note id {nid!r}")
        seen_notes.add(nid)
        _require_str(note, "path", "scope note")
        _require_str(note, "role", "scope note")
        ranges = note.get("line_ranges")
        if (
            not isinstance(ranges, list)
            or not ranges
            or not all(
                isinstance(r, list)
                and len(r) == 2
                and all(isinstance(n, int) and not isinstance(n, bool) for n in r)
                and 1 <= r[0] <= r[1]
                for r in ranges
            )
        ):
            raise _fail(
                f"scope file {path}: note {nid!r} line_ranges must be a non-empty "
                f"list of [start, end] with 1 <= start <= end"
            )
        superseded = note.get("superseded_by", [])
        if not isinstance(superseded, list) or not all(
            isinstance(s, str) for s in superseded
        ):
            raise _fail(
                f"scope file {path}: note {nid!r} superseded_by must be a string list"
            )

    services = scope.get("services")
    if not isinstance(services, list):
        raise _fail(f"scope file {path}: 'services' must be a list")
    for svc in services:
        if not isinstance(svc, dict):
            raise _fail(f"scope file {path}: each service must be an object")
        sid = _require_str(svc, "id", "scope service")
        if not ID_RE.match(sid):
            raise _fail(
                f"scope file {path}: service id {sid!r} is not a safe identifier"
            )
        _require_str(svc, "unit", "scope service")
        manager = svc.get("manager", "system")
        if manager not in ("system", "user"):
            raise _fail(
                f"scope file {path}: service {sid!r} manager must be "
                f"'system' or 'user', got {manager!r}"
            )

    interfaces = scope.get("interfaces", [])
    if not isinstance(interfaces, list):
        raise _fail(f"scope file {path}: 'interfaces' must be a list")

    readers = scope.get("outcome_readers")
    if not isinstance(readers, list):
        raise _fail(f"scope file {path}: 'outcome_readers' must be a list")
    for reader in readers:
        if not isinstance(reader, dict):
            raise _fail(f"scope file {path}: each outcome_reader must be an object")
        oid = _require_str(reader, "id", "scope outcome_reader")
        if not ID_RE.match(oid):
            raise _fail(
                f"scope file {path}: outcome_reader id {oid!r} is not a safe identifier"
            )
        if not isinstance(reader.get("enabled"), bool):
            raise _fail(
                f"scope file {path}: outcome_reader {oid!r} 'enabled' must be boolean"
            )

    qmd = scope.get("qmd")
    if not isinstance(qmd, dict) or not isinstance(qmd.get("enabled"), bool):
        raise _fail(f"scope file {path}: 'qmd' must be an object with boolean 'enabled'")
    queries = qmd.get("queries", [])
    if not isinstance(queries, list):
        raise _fail(f"scope file {path}: qmd.queries must be a list")
    if len(queries) > 3:
        raise _fail(f"scope file {path}: qmd.queries accepts at most 3 queries")
    for query in queries:
        if not isinstance(query, dict):
            raise _fail(f"scope file {path}: each qmd query must be an object")
        _require_str(query, "terms", "scope qmd query")
        if len(query["terms"]) > 200:
            raise _fail(f"scope file {path}: qmd query terms exceed 200 chars")

    limits = scope.get("limits")
    if not isinstance(limits, dict):
        raise _fail(f"scope file {path}: 'limits' must be an object")
    timeout = limits.get("timeout_seconds")
    max_bytes = limits.get("max_bytes")
    if (
        not isinstance(timeout, int)
        or isinstance(timeout, bool)
        or not 1 <= timeout <= 120
    ):
        raise _fail(
            f"scope file {path}: limits.timeout_seconds must be an int 1..120"
        )
    if (
        not isinstance(max_bytes, int)
        or isinstance(max_bytes, bool)
        or not 256 <= max_bytes <= 65536
    ):
        raise _fail(f"scope file {path}: limits.max_bytes must be an int 256..65536")
    return scope


def apply_overrides(
    scope: dict,
    *,
    nixos_repo: str | None = None,
    ca_repo: str | None = None,
    personal_root: str | None = None,
    wiki_root: str | None = None,
) -> dict:
    """Explicit CLI path overrides for configured scope defaults.

    Repository overrides replace the matching configured repository path (by
    id) and any note path rooted at the replaced default. Personal/wiki root
    overrides re-root note paths under the corresponding default root.

    Deterministic behavior: every supplied override must match at least one
    configured path. An override that matches nothing raises ValueError
    instead of silently doing nothing (e.g. --personal-root against a custom
    fixture scope with no Personal-rooted notes). Callers surface this as a
    CLI error (exit 2). Successful overrides only touch the matching scope
    paths; nothing is silently shadowed.
    """
    import copy

    scope = copy.deepcopy(scope)
    renames: list[tuple[str, str]] = []
    if nixos_repo:
        renames.append((DEFAULT_NIXOS_ROOT, nixos_repo))
    if ca_repo:
        renames.append((DEFAULT_CA_ROOT, ca_repo))
    if personal_root:
        renames.append((DEFAULT_PERSONAL_ROOT, personal_root))
    if wiki_root:
        renames.append((DEFAULT_WIKI_ROOT, wiki_root))

    def reroute(path: str) -> str:
        for old, new in renames:
            if path == old or path.startswith(old + os.sep):
                return new + path[len(old):]
        return path

    if nixos_repo:
        matched = [r for r in scope["repositories"] if r.get("id") == "nixos"]
        if not matched:
            raise _fail(
                f"--nixos-repo {nixos_repo!r} matched no configured "
                f"repository (no repository id 'nixos' in scope)"
            )
        for repo in matched:
            repo["path"] = nixos_repo
    if ca_repo:
        matched = [r for r in scope["repositories"] if r.get("id") == "ca"]
        if not matched:
            raise _fail(
                f"--ca-repo {ca_repo!r} matched no configured "
                f"repository (no repository id 'ca' in scope)"
            )
        for repo in matched:
            repo["path"] = ca_repo
    if renames:
        personal_hits = 0
        wiki_hits = 0
        for note in scope["notes"]:
            original = note["path"]
            routed = reroute(original)
            note["path"] = routed
            if routed != original:
                if personal_root and (
                    original == DEFAULT_PERSONAL_ROOT
                    or original.startswith(DEFAULT_PERSONAL_ROOT + os.sep)
                ):
                    personal_hits += 1
                if wiki_root and (
                    original == DEFAULT_WIKI_ROOT
                    or original.startswith(DEFAULT_WIKI_ROOT + os.sep)
                ):
                    wiki_hits += 1
                # CA/nixos-rooted notes rerouted by --ca-repo/--nixos-repo
                # count as matched via the repository branches above.
        if personal_root and personal_hits == 0:
            raise _fail(
                f"--personal-root {personal_root!r} matched no configured "
                f"note path under {DEFAULT_PERSONAL_ROOT!r}"
            )
        if wiki_root and wiki_hits == 0:
            raise _fail(
                f"--wiki-root {wiki_root!r} matched no configured "
                f"note path under {DEFAULT_WIKI_ROOT!r}"
            )
    return scope


def default_runner(cmd: list[str], timeout: int, max_bytes: int = 16384):
    """Fixed-adapter subprocess runner with truly bounded collection.

    No shell, fixed argv only (callers pass fixed git/systemctl/qmd argv;
    scope supplies only path operands, never command strings). Stdout/stderr
    are streamed in 8 KiB chunks on dedicated threads so neither pipe can
    grow without bound: only the first ``max_bytes`` bytes per stream are
    retained; the remainder is drained and discarded to avoid deadlock. Total
    wall time is bounded by ``timeout`` (TimeoutExpired on overrun, killed).
    Returns a namespace with ``returncode``, decoded ``stdout``/``stderr``
    (errors replaced), and ``truncated`` (either stream exceeded max_bytes).
    """
    import threading
    from types import SimpleNamespace

    if isinstance(cmd, str):
        raise ValueError("default_runner requires argv list, not a command string")
    if not isinstance(cmd, list) or not cmd or not all(
        isinstance(part, str) for part in cmd
    ):
        raise ValueError("default_runner requires a non-empty argv string list")
    cap = int(max_bytes) if isinstance(max_bytes, int) else 16384
    if cap < 256:
        cap = 256
    proc = subprocess.Popen(  # noqa: S603 - fixed argv, shell=False always
        list(cmd),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=False,
        text=False,
    )
    assert proc.stdout is not None and proc.stderr is not None
    buffers: dict[str, bytearray] = {"stdout": bytearray(), "stderr": bytearray()}
    totals = {"stdout": 0, "stderr": 0}

    def _pump(pipe, key: str) -> None:
        try:
            while True:
                chunk = pipe.read(8192)
                if not chunk:
                    break
                totals[key] += len(chunk)
                buf = buffers[key]
                if len(buf) < cap + 1:
                    buf.extend(chunk[: cap + 1 - len(buf)])
        except Exception:
            pass
        finally:
            try:
                pipe.close()
            except Exception:
                pass

    threads = [
        threading.Thread(target=_pump, args=(proc.stdout, "stdout"), daemon=True),
        threading.Thread(target=_pump, args=(proc.stderr, "stderr"), daemon=True),
    ]
    for thread in threads:
        thread.start()
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            proc.kill()
        except Exception:
            pass
        try:
            proc.wait(timeout=5)
        except Exception:
            pass
        for thread in threads:
            thread.join(timeout=2)
        raise
    for thread in threads:
        thread.join(timeout=5)
    truncated = totals["stdout"] > cap or totals["stderr"] > cap
    stdout = bytes(buffers["stdout"][:cap]).decode("utf-8", errors="replace")
    stderr = bytes(buffers["stderr"][:cap]).decode("utf-8", errors="replace")
    return SimpleNamespace(
        returncode=proc.returncode, stdout=stdout, stderr=stderr, truncated=truncated
    )


def _bounded(text: str, cap: int) -> tuple[str, bool]:
    if len(text) > cap:
        return text[:cap], True
    return text, False


def _err_diagnostic(text: str, cap: int = 500) -> str:
    """Bounded safe diagnostic: single line, truncated, no dumps."""
    flat = " ".join(str(text).split())
    if len(flat) > cap:
        return flat[:cap] + "…"
    return flat


class Collector:
    """Bounded read-only collectors with explicit errors."""

    def __init__(self, scope: dict, *, now_fn=None, runner=None) -> None:
        self.scope = scope
        self.now_fn = now_fn
        self.runner = runner if runner is not None else default_runner
        limits = scope["limits"]
        self.timeout: int = int(limits["timeout_seconds"])
        self.max_bytes: int = int(limits["max_bytes"])
        self.now = utc_now_iso(now_fn)
        self.sources: list[dict] = []
        self.observations: list[dict] = []
        self.errors: list[dict] = []

    # -- record helpers -------------------------------------------------
    def add_source(self, sid: str, kind: str, ref: str, extra: dict | None = None) -> str:
        record: dict = {
            "id": sid,
            "kind": kind,
            "ref": ref,
            "retrieved_at": self.now,
        }
        if extra:
            record.update(extra)
        self.sources.append(record)
        return sid

    def add_observation(
        self,
        oid: str,
        kind: str,
        source_id: str,
        layer: str,
        facts: dict,
    ) -> str:
        assert layer in LAYERS, layer
        self.observations.append(
            {
                "id": oid,
                "kind": kind,
                "source_id": source_id,
                "observed_at": self.now,
                "layer": layer,
                "facts": facts,
            }
        )
        return oid

    def add_error(self, operation: str, source: str, message: str) -> None:
        self.errors.append(
            {
                "operation": operation,
                "source": source,
                "message": _err_diagnostic(message),
                "observed_at": self.now,
            }
        )

    def run_cmd(self, argv: list[str], source: str, operation: str):
        """Run a fixed argv via the injected runner. Returns proc or None.

        The production runner streams both pipes with a byte cap
        (self.max_bytes); injected fixture runners may accept either
        (cmd, timeout) or (cmd, timeout, max_bytes). A runner-provided
        ``truncated`` flag is preserved on the returned proc when present.
        """
        import inspect

        try:
            try:
                sig = inspect.signature(self.runner)
                params = list(sig.parameters.values())
                accepts_three = any(
                    p.kind == inspect.Parameter.VAR_POSITIONAL for p in params
                ) or len(
                    [
                        p
                        for p in params
                        if p.kind
                        in (
                            inspect.Parameter.POSITIONAL_ONLY,
                            inspect.Parameter.POSITIONAL_OR_KEYWORD,
                        )
                    ]
                ) >= 3
            except (TypeError, ValueError):
                accepts_three = self.runner is default_runner
            if accepts_three:
                proc = self.runner(list(argv), self.timeout, self.max_bytes)
            else:
                proc = self.runner(list(argv), self.timeout)
        except FileNotFoundError:
            self.add_error(operation, source, f"command not found: {argv[0]}")
            return None
        except subprocess.TimeoutExpired:
            self.add_error(
                operation, source, f"timed out after {self.timeout}s: {argv[0]}"
            )
            return None
        except Exception as exc:  # never let a probe crash collection
            self.add_error(operation, source, f"runner failure: {exc}")
            return None
        return proc

    # -- adapters -------------------------------------------------------
    def collect_git(self, repo: dict) -> dict:
        rid = repo["id"]
        path = repo["path"]
        sid = self.add_source(f"repo-{rid}", "git", path)
        oid = f"git-{rid}"
        head_proc = self.run_cmd(
            ["git", "-C", path, "rev-parse", "HEAD"], sid, "git rev-parse"
        )
        if head_proc is None:
            self.add_observation(
                oid, "git", sid, "unknown", {"path": path, "present": False}
            )
            return {"head": None, "ok": False}
        if head_proc.returncode != 0:
            self.add_error(
                "git rev-parse", sid, getattr(head_proc, "stderr", "") or "git failed"
            )
            self.add_observation(
                oid, "git", sid, "unknown", {"path": path, "present": False}
            )
            return {"head": None, "ok": False}
        head = (getattr(head_proc, "stdout", "") or "").strip().split()[0:1]
        head = head[0] if head else ""
        status_proc = self.run_cmd(
            ["git", "-C", path, "status", "--porcelain=v1", "--untracked-files=normal"],
            sid,
            "git status",
        )
        if status_proc is None:
            # run_cmd already recorded an explicit bounded "git status" error
            # (timeout, missing binary, or runner failure); the working-tree
            # state is therefore unknown, never clean.
            self.add_observation(
                oid, "git", sid, "unknown", {"path": path, "present": False}
            )
            return {"head": head, "ok": False}
        if status_proc.returncode != 0:
            self.add_error(
                "git status", sid, f"git status failed with exit {status_proc.returncode}"
            )
            self.add_observation(
                oid, "git", sid, "unknown", {"path": path, "present": False}
            )
            return {"head": head, "ok": False}
        changed_paths: list[str] = []
        untracked_paths: list[str] = []
        changed_count = 0
        untracked_count = 0
        dirty = False
        status_truncated = bool(getattr(status_proc, "truncated", False))
        if status_proc is not None and status_proc.returncode == 0:
            for line in (getattr(status_proc, "stdout", "") or "").splitlines():
                entry = line[3:].strip() if len(line) > 3 else line.strip()
                if not entry:
                    continue
                # Untracked entries ("?? path") are path-status metadata only:
                # record the bounded path, never file contents.
                is_untracked = line.startswith("??")
                changed_count += 1
                if len(changed_paths) < 50:
                    changed_paths.append(entry[:200])
                else:
                    status_truncated = True
                if is_untracked:
                    untracked_count += 1
                    if len(untracked_paths) < 50:
                        untracked_paths.append(entry[:200])
            dirty = changed_count > 0
        # dirty state is path-status metadata only: never diff bodies,
        # never remote URLs or credential config.
        self.add_observation(
            oid,
            "git",
            sid,
            "declared",
            {
                "path": path,
                "head": head[:128],
                "dirty": dirty,
                "changed_paths": changed_paths,
                "changed_count": changed_count,
                "untracked_paths": untracked_paths,
                "untracked_count": untracked_count,
                "truncated": status_truncated,
            },
        )
        return {"head": head, "ok": True}

    def collect_pins(self, repo_paths: dict[str, str]) -> dict[str, dict]:
        """Read selected flake.lock inputs. Returns {input: {rev, ok}}."""
        pins = self.scope["pins"]
        lock_repo = pins["repository"]
        lock_path = os.path.join(repo_paths.get(lock_repo, ""), pins["file"])
        results: dict[str, dict] = {}
        try:
            with open(lock_path, "r", encoding="utf-8", errors="replace") as handle:
                lock = json.load(handle)
        except FileNotFoundError:
            for name in pins["inputs"]:
                sid = self.add_source(f"pin-{name}", "flake_lock", lock_path)
                self.add_observation(
                    f"flake-input-{name}",
                    "flake_input",
                    sid,
                    "unknown",
                    {"input": name, "lock": lock_path, "present": False},
                )
                self.add_error("read flake.lock", sid, f"not found: {lock_path}")
                results[name] = {"rev": None, "ok": False}
            return results
        except (OSError, ValueError) as exc:
            for name in pins["inputs"]:
                sid = self.add_source(f"pin-{name}", "flake_lock", lock_path)
                self.add_observation(
                    f"flake-input-{name}",
                    "flake_input",
                    sid,
                    "unknown",
                    {"input": name, "lock": lock_path, "present": False},
                )
                self.add_error("read flake.lock", sid, f"unreadable lock: {exc}")
                results[name] = {"rev": None, "ok": False}
            return results
        nodes = lock.get("nodes", {}) if isinstance(lock, dict) else {}
        root_inputs = {}
        try:
            root_node = nodes.get("root", {})
            if isinstance(root_node, dict):
                maybe_inputs = root_node.get("inputs", {})
                if isinstance(maybe_inputs, dict):
                    root_inputs = maybe_inputs
        except AttributeError:
            root_inputs = {}

        def _locked_rev(name: str):
            # Resolve through the root inputs mapping first (flake.lock names
            # the node indirectly), falling back to a same-named node.
            for candidate in (root_inputs.get(name), name):
                if not isinstance(candidate, str) or not candidate:
                    continue
                try:
                    node = nodes.get(candidate, {})
                    locked = node.get("locked", {}) if isinstance(node, dict) else {}
                    rev = locked.get("rev") if isinstance(locked, dict) else None
                except AttributeError:
                    rev = None
                if isinstance(rev, str) and rev:
                    return rev
            return None

        for name in pins["inputs"]:
            sid = self.add_source(f"pin-{name}", "flake_lock", lock_path)
            rev = _locked_rev(name)
            if isinstance(rev, str) and rev:
                self.add_observation(
                    f"flake-input-{name}",
                    "flake_input",
                    sid,
                    "declared",
                    {"input": name, "lock": lock_path, "rev": rev[:128]},
                )
                results[name] = {"rev": rev, "ok": True}
            else:
                self.add_observation(
                    f"flake-input-{name}",
                    "flake_input",
                    sid,
                    "unknown",
                    {"input": name, "lock": lock_path, "present": False},
                )
                self.add_error(
                    "read flake.lock", sid, f"input {name!r} has no locked rev"
                )
                results[name] = {"rev": None, "ok": False}
        return results

    def collect_deployment(self) -> None:
        deployment = self.scope["deployment"]
        link = deployment["system"]
        sid = self.add_source("deployment-system", "deployment", link)
        try:
            if os.path.islink(link):
                target = os.readlink(link)
                self.add_observation(
                    "deployment-system",
                    "deployment",
                    sid,
                    "deployed",
                    {"link": link, "target": target[:512]},
                )
            elif os.path.exists(link):
                self.add_observation(
                    "deployment-system",
                    "deployment",
                    sid,
                    "deployed",
                    {"link": link, "target": os.path.realpath(link)[:512]},
                )
            else:
                self.add_observation(
                    "deployment-system",
                    "deployment",
                    sid,
                    "unknown",
                    {"link": link, "present": False},
                )
                self.add_error(
                    "read system generation", sid, f"no system link: {link}"
                )
        except OSError as exc:
            self.add_observation(
                "deployment-system",
                "deployment",
                sid,
                "unknown",
                {"link": link, "present": False},
            )
            self.add_error("read system generation", sid, str(exc))
        for index, candidate in enumerate(deployment.get("user_candidates", [])):
            sid_u = self.add_source(f"deployment-user-{index}", "deployment", candidate)
            oid_u = f"deployment-user-{index}"
            try:
                if os.path.islink(candidate):
                    self.add_observation(
                        oid_u,
                        "deployment",
                        sid_u,
                        "deployed",
                        {
                            "candidate": candidate,
                            "target": os.readlink(candidate)[:512],
                        },
                    )
                elif os.path.exists(candidate):
                    self.add_observation(
                        oid_u,
                        "deployment",
                        sid_u,
                        "deployed",
                        {
                            "candidate": candidate,
                            "target": os.path.realpath(candidate)[:512],
                        },
                    )
                else:
                    # Unknown HM generation is an unknown deployment
                    # observation, not proof HM is absent.
                    self.add_observation(
                        oid_u,
                        "deployment",
                        sid_u,
                        "unknown",
                        {"candidate": candidate, "present": False},
                    )
            except OSError as exc:
                self.add_observation(
                    oid_u,
                    "deployment",
                    sid_u,
                    "unknown",
                    {"candidate": candidate, "present": False},
                )
                self.add_error("read user generation", sid_u, str(exc))

    def collect_note(self, note: dict) -> None:
        nid = note["id"]
        path = note["path"]
        sid = self.add_source(f"note-{nid}", "note", path)
        oid = f"note-{nid}"
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                content = handle.read(self.max_bytes + 1)
        except FileNotFoundError:
            self.add_observation(
                oid, "note", sid, "unknown", {"path": path, "present": False}
            )
            self.add_error("read note", sid, f"not found: {path}")
            return
        except PermissionError:
            self.add_observation(
                oid, "note", sid, "unknown", {"path": path, "present": False}
            )
            self.add_error("read note", sid, f"permission denied: {path}")
            return
        except OSError as exc:
            self.add_observation(
                oid, "note", sid, "unknown", {"path": path, "present": False}
            )
            self.add_error("read note", sid, str(exc))
            return
        truncated = len(content) > self.max_bytes
        if truncated:
            content = content[: self.max_bytes]
        digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
        try:
            mtime = datetime.datetime.fromtimestamp(
                os.stat(path).st_mtime, tz=datetime.timezone.utc
            ).isoformat().replace("+00:00", "Z")
        except OSError:
            mtime = None
        lines = content.splitlines()
        # Only the explicitly selected line ranges enter the packet; anything
        # outside the ranges (including private text) is never cited.
        excerpt_lines: list[str] = []
        for start, end in note["line_ranges"]:
            for lineno in range(start, min(end, len(lines)) + 1):
                excerpt_lines.append(lines[lineno - 1])
        excerpt = "\n".join(excerpt_lines)
        excerpt, excerpt_truncated = _bounded(excerpt, self.max_bytes)
        frontmatter: dict[str, str] = {}
        for line in lines[:40]:
            if len(frontmatter) >= 5:
                break
            match = FRONTMATTER_DATE_RE.match(line.strip())
            if match:
                frontmatter[match.group(1).lower()] = match.group(2)[:200]
        self.add_observation(
            oid,
            "note",
            sid,
            "declared",
            {
                "path": path,
                "line_ranges": note["line_ranges"],
                "excerpt": excerpt,
                "excerpt_truncated": excerpt_truncated or truncated,
                "sha256": digest,
                "mtime_utc": mtime,
                "frontmatter_dates": frontmatter,
                "role": note["role"],
                "superseded_by": note.get("superseded_by", []),
            },
        )

    def collect_service(self, svc: dict) -> None:
        sid_unit = svc["id"]
        unit = svc["unit"]
        manager = svc.get("manager", "system")
        sid = self.add_source(f"service-{sid_unit}", "service", unit)
        oid = f"service-{sid_unit}"
        argv = ["systemctl"]
        if manager == "user":
            argv.append("--user")
        argv += ["show", unit, "-p", ",".join(SERVICE_PROPERTIES)]
        proc = self.run_cmd(argv, sid, "systemctl show")
        if proc is None:
            self.add_observation(
                oid,
                "service",
                sid,
                "unknown",
                {"unit": unit, "manager": manager, "present": False},
            )
            return
        if proc.returncode != 0:
            self.add_error(
                "systemctl show", sid, getattr(proc, "stderr", "") or "systemctl failed"
            )
            self.add_observation(
                oid,
                "service",
                sid,
                "unknown",
                {"unit": unit, "manager": manager, "present": False},
            )
            return
        raw = (getattr(proc, "stdout", "") or "")
        raw, raw_truncated = _bounded(raw, self.max_bytes)
        raw_truncated = raw_truncated or bool(getattr(proc, "truncated", False))
        facts: dict = {"unit": unit, "manager": manager}
        for line in raw.splitlines():
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            if key in SERVICE_PROPERTIES:
                facts[key] = value[:512]
        facts["truncated"] = raw_truncated
        # Availability only: a running service is not completed work and
        # completed work is not demonstrated usefulness.
        if facts.get("ActiveState") == "active" and facts.get("SubState") == "running":
            layer = "verified_available"
        elif facts.get("LoadState") in ("loaded", "masked") or facts.get("ActiveState"):
            layer = "unavailable"
        else:
            layer = "unknown"
        self.add_observation(oid, "service", sid, layer, facts)

    def collect_outcome(self, reader: dict) -> None:
        oid_in = reader["id"]
        sid = self.add_source(f"outcome-{oid_in}", "outcome", oid_in)
        oid = f"outcome-{oid_in}"
        if not reader.get("enabled"):
            # Disabled/unverified outcome sources are unknown, never an
            # empty-success list.
            self.add_observation(
                oid,
                "outcome",
                sid,
                "unknown",
                {
                    "reader": oid_in,
                    "enabled": False,
                    "reason": reader.get("reason", "not configured"),
                },
            )
            return
        path = reader.get("path")
        if not path:
            self.add_observation(
                oid,
                "outcome",
                sid,
                "unknown",
                {"reader": oid_in, "enabled": True, "present": False},
            )
            self.add_error("read outcome", sid, "no verified schema/path")
            return
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                raw = handle.read(self.max_bytes + 1)
        except FileNotFoundError:
            self.add_observation(
                oid,
                "outcome",
                sid,
                "unknown",
                {"reader": oid_in, "enabled": True, "present": False},
            )
            self.add_error("read outcome", sid, f"not found: {path}")
            return
        except PermissionError:
            self.add_observation(
                oid,
                "outcome",
                sid,
                "unknown",
                {"reader": oid_in, "enabled": True, "present": False},
            )
            self.add_error("read outcome", sid, f"permission denied: {path}")
            return
        except OSError as exc:
            self.add_observation(
                oid,
                "outcome",
                sid,
                "unknown",
                {"reader": oid_in, "enabled": True, "present": False},
            )
            self.add_error("read outcome", sid, str(exc))
            return
        truncated = len(raw) > self.max_bytes
        if truncated:
            raw = raw[: self.max_bytes]
        try:
            data = json.loads(raw)
        except ValueError as exc:
            self.add_observation(
                oid,
                "outcome",
                sid,
                "unknown",
                {"reader": oid_in, "enabled": True, "present": False},
            )
            self.add_error("read outcome", sid, f"invalid JSON: {exc}")
            return
        projected = (
            {k: data[k] for k in OUTCOME_FIELDS if k in data}
            if isinstance(data, dict)
            else {}
        )
        self.add_observation(
            oid,
            "outcome",
            sid,
            "verified_available",
            {
                "reader": oid_in,
                "enabled": True,
                "path": path,
                "projected": projected,
                "truncated": truncated,
            },
        )

    def collect_qmd(self) -> None:
        qmd = self.scope.get("qmd", {})
        if not qmd.get("enabled"):
            return
        sid = self.add_source("qmd-status", "qmd", "qmd status")
        proc = self.run_cmd(["qmd", "status"], sid, "qmd status")
        if proc is None:
            self.add_observation(
                "qmd-status", "qmd", sid, "unknown", {"present": False}
            )
            return
        if proc.returncode != 0:
            self.add_error(
                "qmd status", sid, getattr(proc, "stderr", "") or "qmd failed"
            )
            self.add_observation(
                "qmd-status", "qmd", sid, "unknown", {"present": False}
            )
            return
        # Collection status is not note age: keep the raw bounded output and
        # never parse vague relative freshness as a precise timestamp.
        # The production runner streams with a byte cap; fixture runners may
        # return oversized output, so re-bound here and OR the truncation flag.
        output, truncated = _bounded(getattr(proc, "stdout", "") or "", self.max_bytes)
        truncated = truncated or bool(getattr(proc, "truncated", False))
        self.add_observation(
            "qmd-status",
            "qmd",
            sid,
            "verified_available",
            {"output": output, "truncated": truncated},
        )
        for query in qmd.get("queries", []):
            terms = query["terms"]
            collection = query.get("collection", "Personal")
            qid = f"qmd-query-{len(self.observations)}"
            qsid = self.add_source(qid, "qmd", f"qmd search {collection}")
            qproc = self.run_cmd(
                ["qmd", "search", terms, "-c", collection, "--json", "-n", "3"],
                qsid,
                "qmd search",
            )
            if qproc is None or qproc.returncode != 0:
                if qproc is not None and qproc.returncode != 0:
                    self.add_error(
                        "qmd search",
                        qsid,
                        getattr(qproc, "stderr", "") or "qmd search failed",
                    )
                self.add_observation(
                    qid, "qmd", qsid, "unknown",
                    {"terms": terms, "collection": collection, "present": False},
                )
                continue
            out, trunc = _bounded(
                getattr(qproc, "stdout", "") or "", self.max_bytes
            )
            trunc = trunc or bool(getattr(qproc, "truncated", False))
            self.add_observation(
                qid,
                "qmd",
                qsid,
                "verified_available",
                {
                    "terms": terms,
                    "collection": collection,
                    "output": out,
                    "truncated": trunc,
                },
            )


def collect_packet(
    scope: dict,
    *,
    scope_label: str = "scope.json",
    now_fn=None,
    runner=None,
    overrides: dict | None = None,
) -> dict:
    """Collect one research-state packet from scope. Never raises for probes."""
    collector = Collector(scope, now_fn=now_fn, runner=runner)
    repo_paths = {repo["id"]: repo["path"] for repo in scope["repositories"]}
    git_results: dict[str, dict] = {}
    for repo in scope["repositories"]:
        git_results[repo["id"]] = collector.collect_git(repo)
    pin_results = collector.collect_pins(repo_paths)
    collector.collect_deployment()
    for note in scope["notes"]:
        collector.collect_note(note)
    for svc in scope.get("services", []):
        collector.collect_service(svc)
    for reader in scope.get("outcome_readers", []):
        collector.collect_outcome(reader)
    collector.collect_qmd()

    comparisons: list[dict] = []
    obs_ids = {ob["id"] for ob in collector.observations}
    for comp in scope["pins"]["comparisons"]:
        left = f"git-{comp['repository']}"
        right = f"flake-input-{comp['input']}"
        git_ok = git_results.get(comp["repository"], {}).get("ok") and left in obs_ids
        pin_ok = pin_results.get(comp["input"], {}).get("ok") and right in obs_ids
        if not git_ok or not pin_ok:
            status = "unknown"
        elif (
            git_results[comp["repository"]].get("head")
            == pin_results[comp["input"]].get("rev")
        ):
            status = "agree"
        else:
            status = "different"
        # Checkout-vs-pin only: working tree/pin divergence never proves
        # deployment divergence, so no deployment comparison is emitted.
        comparisons.append(
            {
                "kind": "checkout_vs_pin",
                "input": comp["input"],
                "repository": comp["repository"],
                "status": status,
                "left": left,
                "right": right,
                "left_rev": git_results.get(comp["repository"], {}).get("head"),
                "right_rev": pin_results.get(comp["input"], {}).get("rev"),
            }
        )

    return {
        "schema": SCHEMA,
        "packet_id": uuid.uuid4().hex,
        "collected_at": collector.now,
        "host": socket.gethostname(),
        "working_object": scope["working_object"],
        "scope_provenance": (
            {"scope": scope_label, "overrides": dict(overrides)}
            if overrides
            else {"scope": scope_label}
        ),
        "sources": collector.sources,
        "observations": collector.observations,
        "errors": collector.errors,
        "comparisons": comparisons,
    }


def validate_packet(packet: object) -> list[str]:
    """Validate packet shape and references. Empty list means valid."""
    errors: list[str] = []
    if not isinstance(packet, dict):
        return ["top level must be an object"]
    if packet.get("schema") != SCHEMA:
        errors.append(f"expected schema {SCHEMA!r}, got {packet.get('schema')!r}")
    if not isinstance(packet.get("packet_id"), str) or not packet.get("packet_id"):
        errors.append("'packet_id' must be a non-empty string")
    collected = packet.get("collected_at")
    if not isinstance(collected, str) or not collected:
        errors.append("'collected_at' must be a non-empty string")
    elif not (collected.endswith("Z") or collected.endswith("+00:00")):
        errors.append("'collected_at' must be a UTC ISO-8601 timestamp (Z)")
    else:
        try:
            parsed = datetime.datetime.fromisoformat(collected.replace("Z", "+00:00"))
        except ValueError:
            errors.append("'collected_at' must be ISO-8601")
        else:
            if parsed.tzinfo is None or parsed.utcoffset() != datetime.timedelta(0):
                errors.append("'collected_at' must be a UTC ISO-8601 timestamp (Z)")
    if not isinstance(packet.get("host"), str) or not packet.get("host"):
        errors.append("'host' must be a non-empty string")
    working = packet.get("working_object")
    if not isinstance(working, dict) or not working.get("id"):
        errors.append("'working_object' must be an object with non-empty 'id'")
    sources = packet.get("sources")
    if not isinstance(sources, list) or not sources:
        errors.append("'sources' must be a non-empty list")
        source_ids: set[str] = set()
    else:
        source_ids = set()
        for src in sources:
            if not isinstance(src, dict):
                errors.append("each source must be an object")
                continue
            if not isinstance(src.get("id"), str) or not src.get("id"):
                errors.append("each source needs a non-empty string 'id'")
                continue
            if src["id"] in source_ids:
                errors.append(f"duplicate source id {src['id']!r}")
                continue
            source_ids.add(src["id"])
            if not isinstance(src.get("ref"), str):
                errors.append(f"source {src['id']!r}: missing string 'ref'")
            if not isinstance(src.get("retrieved_at"), str):
                errors.append(f"source {src['id']!r}: missing string 'retrieved_at'")
    observations = packet.get("observations")
    if not isinstance(observations, list) or not observations:
        errors.append("'observations' must be a non-empty list")
        obs_ids: set[str] = set()
    else:
        obs_ids = set()
        for ob in observations:
            if not isinstance(ob, dict):
                errors.append("each observation must be an object")
                continue
            oid = ob.get("id")
            if not isinstance(oid, str) or not oid:
                errors.append("each observation needs a non-empty string 'id'")
                continue
            if oid in obs_ids:
                errors.append(f"duplicate observation id {oid!r}")
                continue
            obs_ids.add(oid)
            if not isinstance(ob.get("kind"), str) or not ob.get("kind"):
                errors.append(f"observation {oid!r}: missing string 'kind'")
            if ob.get("source_id") not in source_ids:
                errors.append(
                    f"observation {oid!r}: source_id {ob.get('source_id')!r} "
                    f"names no known source"
                )
            if ob.get("layer") not in LAYERS:
                errors.append(
                    f"observation {oid!r}: layer must be one of {list(LAYERS)}, "
                    f"got {ob.get('layer')!r}"
                )
            if not isinstance(ob.get("observed_at"), str):
                errors.append(f"observation {oid!r}: missing string 'observed_at'")
            if not isinstance(ob.get("facts"), dict):
                errors.append(f"observation {oid!r}: missing object 'facts'")
    if not isinstance(packet.get("errors"), list):
        errors.append("'errors' must be a list")
    else:
        for err in packet["errors"]:
            if not isinstance(err, dict) or not err.get("operation"):
                errors.append("each error needs an object with 'operation'")
    comparisons = packet.get("comparisons")
    if not isinstance(comparisons, list):
        errors.append("'comparisons' must be a list")
    else:
        for comp in comparisons:
            if not isinstance(comp, dict):
                errors.append("each comparison must be an object")
                continue
            if comp.get("status") not in COMPARISON_STATUSES:
                errors.append(
                    f"comparison {comp.get('kind')!r}: status must be one of "
                    f"{list(COMPARISON_STATUSES)}, got {comp.get('status')!r}"
                )
            for end in ("left", "right"):
                if comp.get(end) not in obs_ids:
                    errors.append(
                        f"comparison {comp.get('kind')!r}: {end} "
                        f"{comp.get(end)!r} names no known observation"
                    )
    return errors


def render_markdown(packet: dict) -> str:
    """Render a packet as concise Markdown from the same facts as the JSON."""
    lines = [
        f"# research-state {packet.get('schema', '?')}",
        "",
        f"Packet: `{packet.get('packet_id', '?')}`",
        f"Collected at: `{packet.get('collected_at', '?')}`",
        f"Host: `{packet.get('host', '?')}`",
        "",
        f"Working object: `{packet.get('working_object', {}).get('id', '?')}` — "
        f"{packet.get('working_object', {}).get('description', '')}",
        "",
        "## Comparisons",
        "",
        "| kind | status | left | right |",
        "| --- | --- | --- | --- |",
    ]
    for comp in packet.get("comparisons", []):
        lines.append(
            f"| `{comp.get('kind', '?')}` | {comp.get('status', '?')} "
            f"| `{comp.get('left', '?')}` | `{comp.get('right', '?')}` |"
        )
    lines += ["", "## Observations", ""]
    for ob in packet.get("observations", []):
        facts = ob.get("facts", {})
        lines.append(
            f"### `{ob.get('id', '?')}` — {ob.get('kind', '?')} "
            f"({ob.get('layer', '?')})"
        )
        lines.append("")
        detail_parts: list[str] = []
        for key in (
            "head",
            "rev",
            "dirty",
            "changed_count",
            "link",
            "target",
            "candidate",
            "path",
            "lock",
            "input",
            "unit",
            "manager",
            "ActiveState",
            "SubState",
            "LoadState",
            "Result",
            "reason",
            "present",
        ):
            if key in facts:
                detail_parts.append(f"{key}: {facts[key]}")
        if detail_parts:
            lines.append("- " + "; ".join(str(p) for p in detail_parts))
        if isinstance(facts.get("excerpt"), str) and facts["excerpt"]:
            lines.append("")
            lines.append("Excerpt (selected ranges only):")
            lines.append("```text")
            lines.append(facts["excerpt"][:4000])
            lines.append("```")
        if isinstance(facts.get("output"), str) and facts["output"]:
            lines.append("")
            lines.append("```text")
            lines.append(facts["output"][:2000])
            lines.append("```")
        lines.append("")
    errors = packet.get("errors", [])
    lines.append("## Errors")
    lines.append("")
    if errors:
        for err in errors:
            lines.append(
                f"- `{err.get('operation', '?')}` "
                f"({err.get('source', '?')}): {err.get('message', '')}"
            )
    else:
        lines.append("None.")
    lines.append("")
    lines.append("## Sources")
    lines.append("")
    for src in packet.get("sources", []):
        lines.append(
            f"- `{src.get('id', '?')}` ({src.get('kind', '?')}): "
            f"{src.get('ref', '?')}"
        )
    lines.append("")
    return "\n".join(lines)


def render_text(packet: dict) -> str:
    """Compact plain-text rendering of the same packet facts."""
    lines = [
        f"research-state {packet.get('schema', '?')}",
        f"packet: {packet.get('packet_id', '?')}",
        f"collected_at: {packet.get('collected_at', '?')}",
        f"host: {packet.get('host', '?')}",
        "",
    ]
    for comp in packet.get("comparisons", []):
        lines.append(
            f"[{comp.get('kind', '?')}] {comp.get('status', '?')} "
            f"{comp.get('left', '?')} vs {comp.get('right', '?')}"
        )
    lines.append("")
    for ob in packet.get("observations", []):
        lines.append(
            f"[{ob.get('id', '?')}] {ob.get('kind', '?')}/{ob.get('layer', '?')}"
        )
    if packet.get("errors"):
        lines.append("")
        for err in packet["errors"]:
            lines.append(
                f"error {err.get('operation', '?')} "
                f"({err.get('source', '?')}): {err.get('message', '')}"
            )
    lines.append("")
    return "\n".join(lines)


def ensure_private_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(path, 0o700)
    except OSError:
        pass
    return path


def atomic_write_private(dest: Path, data: bytes) -> None:
    """Atomic 0600 write. Destinations are unique; never overwrite."""
    dest = Path(dest)
    if dest.exists():
        raise FileExistsError(f"refusing to overwrite existing file: {dest}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(dest.parent), prefix=dest.name + ".tmp.")
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, dest)
        os.chmod(dest, 0o600)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def persist_packet(packet: dict, state_dir: Path) -> tuple[Path, Path]:
    """Persist immutable unique timestamped JSON + Markdown packets."""
    ensure_private_dir(state_dir)
    stamp = re.sub(r"[^A-Za-z0-9-]", "", packet["collected_at"].replace(":", ""))
    base = f"{stamp}-{packet['packet_id'][:12]}"
    json_path = state_dir / f"{base}.json"
    md_path = state_dir / f"{base}.md"
    atomic_write_private(
        json_path, (json.dumps(packet, indent=2, sort_keys=True) + "\n").encode("utf-8")
    )
    atomic_write_private(md_path, render_markdown(packet).encode("utf-8"))
    return json_path, md_path


def load_packet_file(path: Path) -> dict:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"cannot read packet {path}: {exc.strerror or exc}") from exc
    try:
        packet = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"packet {path} is not valid JSON: {exc}") from exc
    return packet


def cmd_collect(args: argparse.Namespace) -> int:
    try:
        scope = load_scope(args.scope)
    except ValueError as exc:
        print(f"research-state collect: {exc}", file=sys.stderr)
        return 2
    try:
        scope = apply_overrides(
            scope,
            nixos_repo=args.nixos_repo,
            ca_repo=args.ca_repo,
            personal_root=args.personal_root,
            wiki_root=args.wiki_root,
        )
    except ValueError as exc:
        print(f"research-state collect: {exc}", file=sys.stderr)
        return 2
    overrides_report = {
        k: v
        for k, v in {
            "nixos_repo": args.nixos_repo,
            "ca_repo": args.ca_repo,
            "personal_root": args.personal_root,
            "wiki_root": args.wiki_root,
        }.items()
        if v
    }
    packet = collect_packet(
        scope, scope_label=str(args.scope), overrides=overrides_report or None
    )
    problems = validate_packet(packet)
    if problems:
        print("research-state collect: internally invalid packet:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    state_dir = Path(args.state_dir) if args.state_dir else _default_state_dir()
    try:
        json_path, md_path = persist_packet(packet, state_dir)
    except (OSError, FileExistsError) as exc:
        print(f"research-state collect: cannot persist packet: {exc}", file=sys.stderr)
        return 1
    print(f"collected {packet['packet_id']} -> {json_path}")
    print(f"rendered -> {md_path}")
    return 0


def cmd_render(args: argparse.Namespace) -> int:
    packet_path = Path(args.packet or args.input)
    try:
        packet = load_packet_file(packet_path)
    except ValueError as exc:
        print(f"research-state render: {exc}", file=sys.stderr)
        return 2
    errors = validate_packet(packet)
    if errors:
        print("research-state render: input is not valid research-state:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    if args.format == "text":
        sys.stdout.write(render_text(packet))
    else:
        sys.stdout.write(render_markdown(packet))
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    packet_path = Path(args.packet or args.input)
    try:
        packet = load_packet_file(packet_path)
    except ValueError as exc:
        print(f"research-state validate: {exc}", file=sys.stderr)
        return 2
    errors = validate_packet(packet)
    if errors:
        print(f"research-state validate: INVALID {packet_path}", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print(f"research-state validate: OK {packet_path}")
    return 0


def _is_utc_z(value: object) -> bool:
    """True when value is a UTC ISO-8601 timestamp (Z)."""
    if not isinstance(value, str) or not value:
        return False
    if not (value.endswith("Z") or value.endswith("+00:00")):
        return False
    try:
        parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None and parsed.utcoffset() == datetime.timedelta(0)


def _cited_refs(sections: object) -> tuple[set[str], set[str]]:
    """Collect (source_ids, observation_ids) cited inside evidence sections."""
    sources: set[str] = set()
    observations: set[str] = set()
    stack: list[object] = [sections]
    while stack:
        current = stack.pop()
        if isinstance(current, dict):
            sid = current.get("source_id")
            if isinstance(sid, str) and sid:
                sources.add(sid)
            oid = current.get("observation_id")
            if isinstance(oid, str) and oid:
                observations.add(oid)
            stack.extend(current.values())
        elif isinstance(current, list):
            stack.extend(current)
    return sources, observations


def _packet_ref_index(packet: object) -> tuple[set[str], dict] | None:
    """Return (source_ids, observations_by_id) for a packet, else None."""
    if not isinstance(packet, dict):
        return None
    sources = packet.get("sources")
    observations = packet.get("observations")
    if not isinstance(sources, list) or not isinstance(observations, list):
        return None
    source_ids = {s.get("id") for s in sources if isinstance(s, dict)}
    obs_by_id = {o.get("id"): o for o in observations if isinstance(o, dict)}
    return source_ids, obs_by_id


def _check_refs_against_packet(
    errors: list[str],
    where: str,
    sections: object,
    packet: dict,
    record_packet_id: str,
) -> None:
    """Reject refs that name no source/observation in the linked packet."""
    if packet.get("packet_id") != record_packet_id:
        errors.append(
            f"{where}: packet_id {record_packet_id!r} does not match reference "
            f"packet {packet.get('packet_id')!r}; re-link to a fresh packet"
        )
        return
    index = _packet_ref_index(packet)
    if index is None:
        errors.append(f"{where}: reference packet has no usable sources/observations")
        return
    source_ids, obs_by_id = index
    cited_sources, cited_obs = _cited_refs(sections)
    for sid in sorted(cited_sources):
        if sid not in source_ids:
            errors.append(
                f"{where}: dangling source ref {sid!r} (names no packet source)"
            )
    for oid in sorted(cited_obs):
        if oid not in obs_by_id:
            errors.append(
                f"{where}: dangling observation ref {oid!r} "
                f"(names no packet observation)"
            )


def _validate_candidate(cand: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(cand, dict):
        return ["each candidate must be an object"]
    cid = cand.get("id", "?")
    if not isinstance(cand.get("id"), str) or not cand.get("id"):
        errors.append("each candidate needs a non-empty string 'id'")
    elif not ID_RE.match(cand["id"]):
        errors.append(f"candidate {cid!r}: id is not a safe identifier")
    interfaces = cand.get("interfaces")
    if not isinstance(interfaces, dict):
        errors.append(
            f"candidate {cid!r}: 'interfaces' must be an object with "
            f"'inputs'/'outputs' (compatible interfaces)"
        )
    else:
        for end in ("inputs", "outputs"):
            if not isinstance(interfaces.get(end), list):
                errors.append(
                    f"candidate {cid!r}: interfaces.{end} must be a list "
                    f"(compatible interfaces)"
                )
    if not cand.get("access_constraints"):
        errors.append(f"candidate {cid!r}: missing 'access_constraints'")
    evidence = cand.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        errors.append(
            f"candidate {cid!r}: 'evidence' must be a non-empty list "
            f"(actual evidence, not inference)"
        )
    else:
        for item in evidence:
            if isinstance(item, str):
                if not item:
                    errors.append(f"candidate {cid!r}: empty evidence entry")
            elif isinstance(item, dict):
                if not (
                    item.get("description")
                    or item.get("observation_id")
                    or item.get("source_id")
                ):
                    errors.append(
                        f"candidate {cid!r}: evidence entries need "
                        f"'description' or a packet ref"
                    )
            else:
                errors.append(
                    f"candidate {cid!r}: evidence entries must be strings or objects"
                )
    prereqs = cand.get("prerequisites", [])
    if not isinstance(prereqs, list):
        errors.append(f"candidate {cid!r}: 'prerequisites' must be a list")
    else:
        for pre in prereqs:
            if not isinstance(pre, dict) or not pre.get("id"):
                errors.append(
                    f"candidate {cid!r}: each prerequisite needs "
                    f"an object with 'id'"
                )
                continue
            if pre.get("status") not in PREREQ_STATUSES:
                errors.append(
                    f"candidate {cid!r}: prerequisite {pre.get('id')!r} status "
                    f"must be one of {list(PREREQ_STATUSES)}"
                )
    if not cand.get("why_now"):
        errors.append(f"candidate {cid!r}: missing 'why_now' (why this matters now)")
    if not isinstance(cand.get("alternatives"), list):
        errors.append(f"candidate {cid!r}: 'alternatives' must be a list")
    if not cand.get("disconfirming_evidence"):
        errors.append(
            f"candidate {cid!r}: missing 'disconfirming_evidence' "
            f"(alternatives and disconfirming evidence required)"
        )
    return errors


def validate_salience(record: object) -> list[str]:
    """Validate salience record shape. Empty list means shape-valid.

    Shape only: passing never establishes intent, meaning, usefulness, or
    authorization. Reference checks against a packet need
    check_salience_refs(); stores run both.
    """
    errors: list[str] = []
    if not isinstance(record, dict):
        return ["top level must be an object"]
    if record.get("schema") != SALIENCE_SCHEMA:
        errors.append(
            f"expected schema {SALIENCE_SCHEMA!r}, got {record.get('schema')!r}"
        )
    if not isinstance(record.get("salience_id"), str) or not record.get("salience_id"):
        errors.append("'salience_id' must be a non-empty string")
    if not _is_utc_z(record.get("created_at")):
        errors.append("'created_at' must be a UTC ISO-8601 timestamp (Z)")
    status = record.get("status")
    if status not in SALIENCE_STATUSES:
        errors.append(
            f"'status' must be one of {list(SALIENCE_STATUSES)}, got {status!r}"
        )
    working = record.get("working_object")
    if not isinstance(working, dict) or not working.get("id"):
        errors.append("'working_object' must be an object with non-empty 'id'")
    if not isinstance(record.get("packet_id"), str) or not record.get("packet_id"):
        errors.append("'packet_id' must be a non-empty string (the linked packet)")
    direction = record.get("direction")
    if not isinstance(direction, list) or not direction:
        errors.append(
            "'direction' must be a non-empty list of source-backed direction entries"
        )
    else:
        for entry in direction:
            if isinstance(entry, str):
                if not entry:
                    errors.append("'direction' entries must be non-empty")
            elif isinstance(entry, dict):
                if not entry.get("ref") and not entry.get("description"):
                    errors.append("'direction' entries need 'ref' or 'description'")
            else:
                errors.append("'direction' entries must be strings or objects")
    for key in ("decisions", "boundaries", "open_questions"):
        if key in record and not isinstance(record[key], list):
            errors.append(f"{key!r} must be a list")
    if not isinstance(record.get("observations"), list):
        errors.append(
            "'observations' must be a list (kept distinct from 'interpretations')"
        )
    if not isinstance(record.get("interpretations"), list):
        errors.append(
            "'interpretations' must be a list (judgment, separate from observations)"
        )
    inputs = record.get("inputs", [])
    if not isinstance(inputs, list):
        errors.append("'inputs' must be a list of snapshots with provenance")
    else:
        for snap in inputs:
            if not isinstance(snap, dict):
                errors.append("each 'inputs' snapshot must be an object")
                continue
            if not snap.get("ref"):
                errors.append("each 'inputs' snapshot needs a non-empty 'ref'")
            if not isinstance(snap.get("retrieved_at"), str) or not snap.get(
                "retrieved_at"
            ):
                errors.append(
                    f"input snapshot {snap.get('ref')!r}: missing "
                    f"'retrieved_at' provenance"
                )
            if not isinstance(snap.get("superseded"), bool):
                errors.append(
                    f"input snapshot {snap.get('ref')!r}: missing boolean "
                    f"'superseded' status"
                )
    candidates = record.get("candidates")
    if not isinstance(candidates, list):
        errors.append("'candidates' must be a list (empty is valid: no-candidate)")
        candidates = []
    if len(candidates) > MAX_CANDIDATES:
        errors.append(
            f"'candidates' holds a small set: at most {MAX_CANDIDATES}, "
            f"got {len(candidates)}"
        )
    for cand in candidates:
        errors.extend(_validate_candidate(cand))
    if status in ("no_candidate", "insufficient_evidence"):
        if candidates:
            errors.append(
                f"status {status!r} must carry no candidates; "
                f"move them out or change status"
            )
        gaps = record.get("gaps")
        if not isinstance(gaps, list) or not gaps:
            errors.append(f"status {status!r} must name gaps ('gaps' non-empty)")
    elif status == "candidate":
        if not candidates:
            errors.append("status 'candidate' must carry at least one candidate")
        if not record.get("interpretations"):
            errors.append(
                "status 'candidate' must record 'interpretations' "
                "(observations alone do not interpret)"
            )
    return errors


def check_salience_refs(record: dict, packet: dict) -> list[str]:
    """Reject salience refs that name no source/observation in the packet."""
    errors: list[str] = []
    _check_refs_against_packet(
        errors,
        "salience",
        [record.get("direction"), record.get("inputs"), record.get("candidates")],
        packet,
        record.get("packet_id", ""),
    )
    return errors


def validate_contract(contract: object) -> list[str]:
    """Validate draft-contract shape. Empty list means shape-valid.

    Shape only, never authorization: even a valid contract stays a DRAFT that
    needs fresh evidence and its recorded human gate before anything runs.
    """
    errors: list[str] = []
    if not isinstance(contract, dict):
        return ["top level must be an object"]
    if contract.get("schema") != CONTRACT_SCHEMA:
        errors.append(
            f"expected schema {CONTRACT_SCHEMA!r}, got {contract.get('schema')!r}"
        )
    if not isinstance(contract.get("contract_id"), str) or not contract.get(
        "contract_id"
    ):
        errors.append("'contract_id' must be a non-empty string")
    if not _is_utc_z(contract.get("created_at")):
        errors.append("'created_at' must be a UTC ISO-8601 timestamp (Z)")
    if contract.get("status") != "draft":
        errors.append(
            "'status' must be 'draft': a contract draft never authorizes execution"
        )
    xtype = contract.get("experiment_type")
    if xtype not in EXPERIMENT_TYPES:
        errors.append(
            f"'experiment_type' must be one of {list(EXPERIMENT_TYPES)}, "
            f"got {xtype!r}"
        )
    for key in ("candidate_id", "packet_id"):
        if not isinstance(contract.get(key), str) or not contract.get(key):
            errors.append(f"{key!r} must be a non-empty string (the linked choice)")
    if "salience_id" in contract and not contract["salience_id"]:
        errors.append("'salience_id' must be non-empty when present")
    if not contract.get("intended_capability"):
        errors.append("missing 'intended_capability'")
    direction = contract.get("direction_refs")
    if not isinstance(direction, list) or not direction:
        errors.append(
            "'direction_refs' must be a non-empty list (source-backed direction)"
        )
    else:
        for entry in direction:
            if isinstance(entry, str):
                if not entry:
                    errors.append("'direction_refs' entries must be non-empty")
            elif isinstance(entry, dict):
                if not entry.get("ref") and not entry.get("description"):
                    errors.append(
                        "'direction_refs' entries need 'ref' or 'description'"
                    )
            else:
                errors.append("'direction_refs' entries must be strings or objects")
    evidence = contract.get("computer_evidence")
    if not isinstance(evidence, list) or not evidence:
        errors.append("'computer_evidence' must be a non-empty list")
    else:
        for item in evidence:
            if not isinstance(item, dict) or not item.get("description"):
                errors.append(
                    "each 'computer_evidence' entry needs an object "
                    "with 'description'"
                )
    prereqs = contract.get("prerequisites")
    if not isinstance(prereqs, list) or not prereqs:
        errors.append(
            "'prerequisites' must be a non-empty list (unresolved "
            "prerequisites are retained, never dropped)"
        )
    else:
        for pre in prereqs:
            if not isinstance(pre, dict):
                errors.append("each prerequisite must be an object")
                continue
            if not pre.get("id"):
                errors.append("each prerequisite needs a non-empty 'id'")
            if not pre.get("description"):
                errors.append(
                    f"prerequisite {pre.get('id', '?')!r}: missing 'description'"
                )
            if pre.get("status") not in PREREQ_STATUSES:
                errors.append(
                    f"prerequisite {pre.get('id', '?')!r}: status must be one of "
                    f"{list(PREREQ_STATUSES)}, got {pre.get('status')!r}"
                )
    for key in (
        "hypothesis",
        "mechanism",
        "baseline_plan",
        "falsifying_evidence",
        "protected_behavior",
        "counterexample",
        "reversal",
    ):
        if not contract.get(key):
            errors.append(f"missing {key!r}")
    acceptance = contract.get("acceptance")
    if not isinstance(acceptance, list) or not acceptance:
        errors.append(
            "'acceptance' must be a non-empty list of conditions with stable IDs"
        )
    else:
        for acc in acceptance:
            if not isinstance(acc, dict):
                errors.append("each acceptance condition must be an object")
                continue
            aid = acc.get("id", "?")
            if not acc.get("id"):
                errors.append("each acceptance condition needs a stable non-empty 'id'")
            if not acc.get("description"):
                errors.append(
                    f"acceptance {aid!r}: missing 'description'"
                )
            check = acc.get("check")
            if not isinstance(check, dict):
                errors.append(f"acceptance {aid!r}: missing object 'check'")
                continue
            kind = check.get("kind")
            if kind not in CHECK_KINDS:
                errors.append(
                    f"acceptance {aid!r}: check kind must be one of "
                    f"{list(CHECK_KINDS)}, got {kind!r} (executable where safe, "
                    f"explicit human-review otherwise)"
                )
            elif kind == "executable" and not check.get("command"):
                errors.append(
                    f"acceptance {aid!r}: executable checks need 'command'"
                )
            elif kind == "human_review" and not check.get("review"):
                errors.append(
                    f"acceptance {aid!r}: human-review checks need 'review'"
                )
    authority = contract.get("authority")
    if not isinstance(authority, dict):
        errors.append(
            "'authority' must be an object with exact read/write authority "
            "and bounded targets"
        )
        authority = {}
    else:
        for key in ("reads", "writes"):
            if not isinstance(authority.get(key), list):
                errors.append(f"'authority.{key}' must be a list")
        targets = authority.get("targets")
        if not isinstance(targets, list) or not targets:
            errors.append(
                "'authority.targets' must be a non-empty list (bounded targets); "
                "incomplete authority is rejected as an executable contract"
            )
    limits = contract.get("cost_limits")
    if (
        not isinstance(limits, dict)
        or not limits.get("time")
        or not limits.get("cost")
    ):
        errors.append("'cost_limits' must name time and cost limits")
    gate = contract.get("human_gate")
    if not isinstance(gate, dict) or not isinstance(gate.get("required"), bool):
        errors.append("'human_gate' must be an object with boolean 'required'")
        gate = {}
    elif gate["required"] and not gate.get("reason"):
        errors.append(
            "'human_gate' is pending: 'reason' must say what needs the operator"
        )
    if (
        isinstance(authority, dict)
        and authority.get("writes")
        and isinstance(gate, dict)
        and not gate.get("required")
    ):
        errors.append(
            "consequential writes need a pending human gate "
            "('human_gate.required' must be true)"
        )
    claim = contract.get("capability_claim", "unsupported")
    if claim not in CAPABILITY_CLAIMS:
        errors.append(
            f"'capability_claim' must be one of {list(CAPABILITY_CLAIMS)}, "
            f"got {claim!r}"
        )
    else:
        unresolved = [
            p.get("id", "?")
            for p in prereqs
            if isinstance(p, dict) and p.get("status") != "verified"
        ]
        if claim == "supported" and unresolved:
            errors.append(
                f"unresolved prerequisites {unresolved} block a "
                f"supported-capability claim (keep 'unsupported' or verify them)"
            )
        if claim == "supported" and xtype == "discovery":
            errors.append(
                "a discovery experiment resolves uncertainty; it cannot carry "
                "a supported-capability claim"
            )
    if xtype == "discovery" and not contract.get("uncertainty"):
        errors.append(
            "discovery experiments must record explicit 'uncertainty'"
        )
    return errors


def check_contract_refs(contract: dict, packet: dict) -> list[str]:
    """Reject dangling refs and service-existence-only usefulness claims."""
    errors: list[str] = []
    _check_refs_against_packet(
        errors,
        "contract",
        [contract.get("direction_refs"), contract.get("computer_evidence")],
        packet,
        contract.get("packet_id", ""),
    )
    if errors:
        return errors
    if contract.get("capability_claim") == "supported":
        index = _packet_ref_index(packet)
        if index is None:
            errors.append(
                "a supported-capability claim needs a usable reference packet"
            )
            return errors
        _, obs_by_id = index
        _, cited_obs = _cited_refs([contract.get("computer_evidence")])
        if not cited_obs:
            errors.append(
                "a supported-capability claim needs cited packet observations, "
                "not prose alone"
            )
        else:
            kinds = {obs_by_id[o].get("kind") for o in cited_obs if o in obs_by_id}
            if kinds and kinds <= {"service"}:
                errors.append(
                    "declared-only service existence cannot establish proven "
                    "usefulness; cite outcome/deployment/note evidence or keep "
                    "the claim 'unsupported'"
                )
    return errors


def render_salience_markdown(record: dict) -> str:
    """Render a salience record as readable Markdown from the same facts."""
    working = record.get("working_object", {})
    lines = [
        f"# salience {record.get('schema', '?')}",
        "",
        f"Record: `{record.get('salience_id', '?')}`",
        f"Created at: `{record.get('created_at', '?')}`",
        f"Status: `{record.get('status', '?')}`",
        "",
        f"Working object: `{working.get('id', '?')}` — "
        f"{working.get('description', '')}",
        f"Packet: `{record.get('packet_id', '?')}`",
        "",
        "## Direction (source-backed)",
        "",
    ]
    for entry in record.get("direction", []):
        if isinstance(entry, str):
            lines.append(f"- {entry}")
        else:
            lines.append(
                f"- `{entry.get('ref', '?')}` — {entry.get('description', '')}"
            )
    lines += ["", "## Observations (facts)", ""]
    for ob in record.get("observations", []):
        lines.append(f"- {ob if isinstance(ob, str) else ob.get('description', ob)}")
    lines += ["", "## Interpretations (judgment, not facts)", ""]
    for inter in record.get("interpretations", []):
        lines.append(
            f"- {inter if isinstance(inter, str) else inter.get('description', inter)}"
        )
    lines += ["", "## Candidates", ""]
    for cand in record.get("candidates", []):
        if not isinstance(cand, dict):
            continue
        interfaces = cand.get("interfaces", {})
        lines += [
            f"### `{cand.get('id', '?')}`",
            "",
            f"Compatible inputs: {', '.join(interfaces.get('inputs', [])) or '—'}",
            f"Compatible outputs: {', '.join(interfaces.get('outputs', [])) or '—'}",
            f"Access: {cand.get('access_constraints', '—')}",
            f"Why now: {cand.get('why_now', '—')}",
            "",
            "Evidence:",
            "",
        ]
        for item in cand.get("evidence", []):
            if isinstance(item, str):
                lines.append(f"- {item}")
            else:
                ref = item.get("observation_id") or item.get("source_id") or "—"
                lines.append(f"- `{ref}` — {item.get('description', '')}")
        lines += ["", "Prerequisites:", ""]
        for pre in cand.get("prerequisites", []):
            lines.append(
                f"- `{pre.get('id', '?')}` ({pre.get('status', '?')}) — "
                f"{pre.get('description', '')}"
            )
        lines += [
            "",
            f"Alternatives: {cand.get('alternatives', [])}",
            f"Disconfirming evidence: {cand.get('disconfirming_evidence', '—')}",
            "",
        ]
    if record.get("gaps"):
        lines += ["## Gaps", ""]
        for gap in record["gaps"]:
            lines.append(
                f"- {gap if isinstance(gap, str) else gap.get('description', gap)}"
            )
        lines.append("")
    lines += [
        "_Scores never establish intent or approve a proposal. Observations are "
        "facts; interpretations are Hermes judgment._",
        "",
    ]
    return "\n".join(lines)


def render_contract_markdown(contract: dict) -> str:
    """Render a draft contract as readable Markdown from the same facts."""
    authority = contract.get("authority", {})
    gate = contract.get("human_gate", {})
    lines = [
        f"# experiment contract {contract.get('schema', '?')}",
        "",
        "> DRAFT — shape validation is NOT authorization. NEVER execute merely "
        "because shape validates. Anything consequential waits on the pending "
        "human gate below.",
        "",
        f"Contract: `{contract.get('contract_id', '?')}`",
        f"Created at: `{contract.get('created_at', '?')}`",
        f"Status: `{contract.get('status', '?')}`",
        f"Type: `{contract.get('experiment_type', '?')}` "
        "(capability tests a chosen performance; discovery resolves uncertainty)",
        f"Candidate: `{contract.get('candidate_id', '?')}`",
        f"Packet: `{contract.get('packet_id', '?')}`",
        f"Salience: `{contract.get('salience_id', '—')}`",
        f"Capability claim: `{contract.get('capability_claim', 'unsupported')}`",
        "",
        f"## Intended capability",
        "",
        f"{contract.get('intended_capability', '—')}",
        "",
        "## Direction (source-backed)",
        "",
    ]
    for entry in contract.get("direction_refs", []):
        if isinstance(entry, str):
            lines.append(f"- {entry}")
        else:
            lines.append(
                f"- `{entry.get('ref', '?')}` — {entry.get('description', '')}"
            )
    lines += ["", "## Computer evidence", ""]
    for item in contract.get("computer_evidence", []):
        ref = item.get("observation_id") or item.get("source_id") or "—"
        lines.append(f"- `{ref}` — {item.get('description', '')}")
    lines += ["", "## Prerequisites (unresolved stay listed)", ""]
    for pre in contract.get("prerequisites", []):
        lines.append(
            f"- `{pre.get('id', '?')}` ({pre.get('status', '?')}) — "
            f"{pre.get('description', '')}"
        )
    if contract.get("uncertainty"):
        lines += ["", "## Uncertainty (discovery)", "", f"{contract['uncertainty']}", ""]
    lines += [
        "## Hypothesis (recorded before results)",
        "",
        f"{contract.get('hypothesis', '—')}",
        "",
        "## Proposed mechanism",
        "",
        f"{contract.get('mechanism', '—')}",
        "",
        "## Baseline capture plan",
        "",
        f"{contract.get('baseline_plan', '—')}",
        "",
        "## Acceptance conditions",
        "",
        "| id | condition | check |",
        "| --- | --- | --- |",
    ]
    for acc in contract.get("acceptance", []):
        check = acc.get("check", {})
        if check.get("kind") == "executable":
            detail = f"executable: `{check.get('command', '?')}`"
        else:
            detail = f"human-review: {check.get('review', '?')}"
        lines.append(
            f"| `{acc.get('id', '?')}` | {acc.get('description', '?')} | {detail} |"
        )
    limits = contract.get("cost_limits", {})
    lines += [
        "",
        "## Falsifying evidence",
        "",
        f"{contract.get('falsifying_evidence', '—')}",
        "",
        "## Protected behavior",
        "",
        f"{contract.get('protected_behavior', '—')}",
        "",
        "## Counterexample",
        "",
        f"{contract.get('counterexample', '—')}",
        "",
        "## Authority (exact read/write, bounded targets)",
        "",
        f"Reads: {authority.get('reads', [])}",
        f"Writes: {authority.get('writes', [])}",
        f"Targets: {authority.get('targets', [])}",
        "",
        "## Cost/time limits",
        "",
        f"Time: {limits.get('time', '—')}; Cost: {limits.get('cost', '—')}",
        "",
        "## Reversal/disposal",
        "",
        f"{contract.get('reversal', '—')}",
        "",
        "## Human gate",
        "",
        f"Required: `{gate.get('required', '?')}` — {gate.get('reason', '')}",
        "",
    ]
    return "\n".join(lines)


def _record_stamp(created_at: str, ident: str) -> str:
    stamp = re.sub(r"[^A-Za-z0-9-]", "", (created_at or "undated").replace(":", ""))
    safe_ident = re.sub(r"[^A-Za-z0-9-]", "", ident or "record")[:24]
    return f"{stamp}-{safe_ident}-{uuid.uuid4().hex[:8]}"


def persist_salience(record: dict, state_dir: Path) -> tuple[Path, Path]:
    """Persist a salience record as immutable JSON + Markdown (private)."""
    ensure_private_dir(state_dir)
    base = "salience-" + _record_stamp(
        record.get("created_at", ""), record.get("salience_id", "")
    )
    json_path = state_dir / f"{base}.json"
    md_path = state_dir / f"{base}.md"
    atomic_write_private(
        json_path, (json.dumps(record, indent=2, sort_keys=True) + "\n").encode("utf-8")
    )
    atomic_write_private(md_path, render_salience_markdown(record).encode("utf-8"))
    return json_path, md_path


def persist_contract(contract: dict, state_dir: Path) -> tuple[Path, Path]:
    """Persist a draft contract as immutable JSON + Markdown (private)."""
    ensure_private_dir(state_dir)
    base = "contract-" + _record_stamp(
        contract.get("created_at", ""), contract.get("contract_id", "")
    )
    json_path = state_dir / f"{base}.json"
    md_path = state_dir / f"{base}.md"
    atomic_write_private(
        json_path,
        (json.dumps(contract, indent=2, sort_keys=True) + "\n").encode("utf-8"),
    )
    atomic_write_private(md_path, render_contract_markdown(contract).encode("utf-8"))
    return json_path, md_path


def load_record_file(path: Path) -> dict:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"cannot read record {path}: {exc.strerror or exc}") from exc
    try:
        record = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"record {path} is not valid JSON: {exc}") from exc
    if not isinstance(record, dict):
        raise ValueError(f"record {path}: top level must be an object")
    return record


def load_reference_packet(packet_arg: str | None) -> dict | None:
    """Load and validate a --packet reference file, or None when omitted."""
    if not packet_arg:
        return None
    packet = load_packet_file(Path(packet_arg))
    problems = validate_packet(packet)
    if problems:
        raise ValueError(
            f"reference packet {packet_arg} is not valid research-state: "
            f"{problems[0]}"
        )
    return packet


def cmd_salience_validate(args: argparse.Namespace) -> int:
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state salience-validate: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
    except ValueError as exc:
        print(f"research-state salience-validate: {exc}", file=sys.stderr)
        return 2
    errors = validate_salience(record)
    if packet is not None:
        errors.extend(check_salience_refs(record, packet))
    if errors:
        print(
            f"research-state salience-validate: INVALID {record_path}",
            file=sys.stderr,
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print(
        f"research-state salience-validate: OK {record_path} "
        f"(shape valid — NOT an approval)"
    )
    return 0


def cmd_salience_store(args: argparse.Namespace) -> int:
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state salience-store: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
    except ValueError as exc:
        print(f"research-state salience-store: {exc}", file=sys.stderr)
        return 2
    errors = validate_salience(record)
    if packet is not None:
        errors.extend(check_salience_refs(record, packet))
    if errors:
        print(
            f"research-state salience-store: INVALID {record_path}", file=sys.stderr
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    state_dir = Path(args.state_dir) if args.state_dir else _default_state_dir()
    try:
        json_path, md_path = persist_salience(record, state_dir)
    except (OSError, FileExistsError) as exc:
        print(f"research-state salience-store: cannot persist: {exc}", file=sys.stderr)
        return 1
    print(f"stored {record['salience_id']} -> {json_path}")
    print(f"rendered -> {md_path}")
    return 0


def cmd_contract_validate(args: argparse.Namespace) -> int:
    contract_path = Path(args.contract or args.input)
    try:
        contract = load_record_file(contract_path)
    except ValueError as exc:
        print(f"research-state contract-validate: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
    except ValueError as exc:
        print(f"research-state contract-validate: {exc}", file=sys.stderr)
        return 2
    errors = validate_contract(contract)
    if packet is not None:
        errors.extend(check_contract_refs(contract, packet))
    elif contract.get("capability_claim") == "supported":
        errors.append(
            "a supported-capability claim requires --packet evidence check; "
            "re-validate with the linked packet"
        )
    if errors:
        print(
            f"research-state contract-validate: INVALID {contract_path}",
            file=sys.stderr,
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print(
        f"research-state contract-validate: OK {contract_path} "
        f"(DRAFT shape valid — NOT authorization to execute)"
    )
    return 0


def cmd_contract_store(args: argparse.Namespace) -> int:
    contract_path = Path(args.contract or args.input)
    try:
        contract = load_record_file(contract_path)
    except ValueError as exc:
        print(f"research-state contract-store: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
    except ValueError as exc:
        print(f"research-state contract-store: {exc}", file=sys.stderr)
        return 2
    errors = validate_contract(contract)
    if packet is not None:
        errors.extend(check_contract_refs(contract, packet))
    elif contract.get("capability_claim") == "supported":
        errors.append(
            "a supported-capability claim requires --packet evidence check; "
            "re-validate with the linked packet"
        )
    if errors:
        print(
            f"research-state contract-store: INVALID {contract_path}", file=sys.stderr
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    state_dir = Path(args.state_dir) if args.state_dir else _default_state_dir()
    try:
        json_path, md_path = persist_contract(contract, state_dir)
    except (OSError, FileExistsError) as exc:
        print(f"research-state contract-store: cannot persist: {exc}", file=sys.stderr)
        return 1
    print(f"stored {contract['contract_id']} -> {json_path}")
    print(f"rendered -> {md_path}")
    print("DRAFT stored — shape valid, NOT authorization to execute.")
    return 0


# ---------------------------------------------------------------------------
# Slice C: manual attempt lifecycle (baseline -> result -> decision -> followup)
#
# Bounded manual actions behind the SAME research-state command. Nothing here
# executes experiment commands: acceptance-check `command` strings are
# recorded data, never subprocess input. Hermes/operator runs an authorized,
# reversible experiment outside this collector, then supplies bounded real
# evidence with provenance. Human approval is never automated: a JSON boolean
# is not human consent, so keep decisions require a named reviewer, a
# timestamped review note, and reviewed evidence for every human-required
# check. Failures and discarded attempts persist as immutable attempt
# history, never as successful precedent. Dropped ideas stay dropped unless
# an explicit new-evidence/reopen link changes their basis.
# ---------------------------------------------------------------------------

SECRET_KEY_RE = re.compile(
    r"(password|passwd|secret|api[_-]?key|token|bearer|credential|"
    r"private[_-]?key|client[_-]?secret|auth[_-]?key|session[_-]?key)",
    re.IGNORECASE,
)
SECRET_FIELD_RE = re.compile(
    r"^(env_dump|environment_dump|clipboard|desktop_capture|message_dump|"
    r"process_args|exec_output_full)$",
    re.IGNORECASE,
)
SECRET_NAME_RE = re.compile(
    r"(secret|credential|token|private|password|passwd|\.env$|"
    r"env\.|_env\.|trace|dump|core$|\.hprof|hprof|/proc)",
    re.IGNORECASE,
)

# Slice C content admission: narrow deterministic gates for obvious
# secret/env/trace/process-dump bytes inside otherwise-allowed artifacts.
# These are obvious-pattern rejections only, never a general redaction
# guarantee for arbitrary free text: never put private bytes here in the
# first place. Artifacts whose bytes fall outside the allowed capture scope
# preserve references+hashes via `bytes_outside_scope` instead of ingesting.
_ENV_LINE_RE = re.compile(
    r"(?m)^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\S"
)
_DB_URL_WITH_CREDS_RE = re.compile(
    r"\b(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis)://[^/\s:]+:[^/\s@]+@",
    re.IGNORECASE,
)
_PRIVATE_KEY_RE = re.compile(
    r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----",
    re.IGNORECASE,
)
_PROC_DUMP_RES = (
    re.compile(r"/proc/\d+/(?:cmdline|environ|maps|mem|fd)"),
    re.compile(r"(?m)^\s*USER\s+PID\s+.*COMMAND"),
    re.compile(r"(?m)^\s*PID\s+TTY\b"),
    re.compile(r"argv\[\d+\]"),
    re.compile(r"process arguments", re.IGNORECASE),
)
_TRACE_DUMP_RES = (
    re.compile(r"Traceback \(most recent call last\)"),
    re.compile(r"(?m)^goroutine \d+ \["),
    re.compile(r"Exception in thread"),
    re.compile(r"(?m)^\s*Caused by: "),
)
_STACK_AT_RE = re.compile(r"(?m)^\s*at [\w.$<>]+\([^()]*:\d+[^()]*\)")


def _artifact_content_error(text: str, *, media: object = None) -> str | None:
    """Narrow obvious-dump gate for artifact bytes. None means admitted.

    Rejects: private-key blocks, dotenv-style secret assignments (or any
    dotenv-shaped file with 3+ KEY=value lines), credentialed DB URLs,
    /proc/ps/argv process dumps, Python/Go/Java stack-trace dumps, and
    JSON/JSONL payloads whose keys are secret/env-dump shaped. Everything
    else passes: this never claims general redaction of arbitrary prose.
    """
    if not isinstance(text, str) or not text:
        return None
    if _PRIVATE_KEY_RE.search(text):
        return (
            "artifact bytes look like a private key "
            "(-----BEGIN ... PRIVATE KEY-----): rejected "
            "(preserve references+hashes only, never ingest)"
        )
    if isinstance(media, str) and media in ("json", "jsonl"):
        parsed: object = None
        parse_ok = False
        try:
            if media == "json":
                parsed = json.loads(text)
            else:
                parsed = [
                    json.loads(line)
                    for line in text.splitlines()
                    if line.strip()
                ]
            parse_ok = True
        except ValueError:
            parse_ok = False
        if parse_ok:
            hits = _walk_secret_keys(parsed)
            if hits:
                return (
                    f"artifact JSON keys look secret/env-shaped ({hits[0]}): "
                    f"rejected (preserve references+hashes only, never ingest)"
                )
    env_keys: list[str] = [m.group(1) for m in _ENV_LINE_RE.finditer(text)]
    for key in env_keys:
        if SECRET_KEY_RE.search(key) or "DATABASE_URL" in key.upper():
            return (
                f"artifact bytes look like a secret/env dump ({key}=...): "
                f"rejected (preserve references+hashes only, never ingest)"
            )
    if len(env_keys) >= 3 and all(
        re.fullmatch(r"[A-Z_][A-Z0-9_]*", k) for k in env_keys[:8]
    ):
        return (
            "artifact bytes look like an environment dump "
            f"({len(env_keys)} KEY=value lines): rejected "
            "(preserve references+hashes only, never ingest)"
        )
    if _DB_URL_WITH_CREDS_RE.search(text):
        return (
            "artifact bytes look like a credentialed database URL "
            "(scheme://user:password@...): rejected "
            "(preserve references+hashes only, never ingest)"
        )
    for rx in _PROC_DUMP_RES:
        if rx.search(text):
            return (
                f"artifact bytes look like a process dump ({rx.pattern!r}): "
                f"rejected (preserve references+hashes only, never ingest)"
            )
    for rx in _TRACE_DUMP_RES:
        if rx.search(text):
            return (
                f"artifact bytes look like a trace/log dump ({rx.pattern!r}): "
                f"rejected (preserve references+hashes only, never ingest)"
            )
    if len(_STACK_AT_RE.findall(text)) >= 3:
        return (
            "artifact bytes look like a stack-trace dump "
            "(repeated 'at frame(file:line)' entries): rejected "
            "(preserve references+hashes only, never ingest)"
        )
    return None


def contract_canonical_hash(obj: object) -> str:
    """Canonical sha256 over a contract document (shared by CLI and tests)."""
    canonical = json.dumps(obj, sort_keys=True, separators=(",", ":")).encode(
        "utf-8"
    )
    return hashlib.sha256(canonical).hexdigest()


def _parse_utc(value: object) -> datetime.datetime | None:
    if not isinstance(value, str) or not value:
        return None
    if not (value.endswith("Z") or value.endswith("+00:00")):
        return None
    try:
        parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None or parsed.utcoffset() != datetime.timedelta(0):
        return None
    return parsed


def _artifact_path_error(path: object) -> str | None:
    """Return an error string when an artifact path is unsafe, else None."""
    if not isinstance(path, str) or not path:
        return "artifact 'path' must be a non-empty relative path"
    if os.path.isabs(path):
        return f"artifact path {path!r} must be relative, never absolute"
    parts = path.replace("\\", "/").split("/")
    if any(part in ("", ".", "..") for part in parts):
        return (
            f"artifact path {path!r} must not contain empty, '.', or '..' "
            f"segments (path traversal rejected)"
        )
    lowered = path.lower()
    if not lowered.endswith(ATTEMPT_ARTIFACT_SUFFIXES):
        return (
            f"artifact path {path!r} must use an allowlisted format "
            f"{list(ATTEMPT_ARTIFACT_SUFFIXES)}"
        )
    if SECRET_NAME_RE.search(path):
        return (
            f"artifact path {path!r} names a secret/env/trace/process-dump "
            f"type: rejected (preserve references+hashes only, never ingest)"
        )
    return None


def _walk_secret_keys(obj: object, trail: str = "record") -> list[str]:
    """Find metadata keys that must never appear in attempt records."""
    hits: list[str] = []
    if isinstance(obj, dict):
        for key, value in obj.items():
            where = f"{trail}.{key}" if isinstance(key, str) else trail
            if isinstance(key, str) and (
                SECRET_KEY_RE.search(key) or SECRET_FIELD_RE.match(key)
            ):
                hits.append(where)
            hits.extend(_walk_secret_keys(value, where))
    elif isinstance(obj, list):
        for index, item in enumerate(obj):
            hits.extend(_walk_secret_keys(item, f"{trail}[{index}]"))
    return hits


def _validate_attempt_checks(
    errors: list[str], record: dict, acceptance_ids: list[str]
) -> None:
    baseline_conds = record["baseline"].get("conditions")
    if not isinstance(baseline_conds, list) or not baseline_conds:
        errors.append(
            "'baseline.conditions' must be a non-empty list freezing the "
            "same acceptance conditions before the experiment"
        )
        return
    baseline_status: dict[str, str] = {}
    for cond in baseline_conds:
        if not isinstance(cond, dict) or not cond.get("id"):
            errors.append("each baseline condition needs a non-empty 'id'")
            continue
        if cond.get("status") not in BASELINE_STATUSES:
            errors.append(
                f"baseline condition {cond.get('id')!r}: status must be one of "
                f"{list(BASELINE_STATUSES)}, got {cond.get('status')!r}"
            )
        baseline_status[cond["id"]] = cond.get("status", "?")
    if set(baseline_status) != set(acceptance_ids):
        errors.append(
            "baseline condition IDs must equal the frozen contract "
            f"acceptance_ids {acceptance_ids}; got {sorted(baseline_status)} "
            f"(a changed condition set invalidates comparison — re-baseline "
            f"as a new attempt)"
        )
    result = record.get("result")
    if result is None:
        return
    checks = result.get("checks")
    if not isinstance(checks, list) or not checks:
        errors.append(
            "'result.checks' must be a non-empty list comparing the SAME "
            "acceptance conditions before and after"
        )
        return
    seen: set[str] = set()
    for check in checks:
        if not isinstance(check, dict) or not check.get("id"):
            errors.append("each result check needs a non-empty 'id'")
            continue
        cid = check["id"]
        if cid in seen:
            errors.append(f"duplicate result check id {cid!r}")
            continue
        seen.add(cid)
        if check.get("baseline") not in BASELINE_STATUSES:
            errors.append(
                f"check {cid!r}: 'baseline' must be one of "
                f"{list(BASELINE_STATUSES)}, got {check.get('baseline')!r}"
            )
        elif cid in baseline_status and check["baseline"] != baseline_status[cid]:
            errors.append(
                f"check {cid!r}: recorded baseline {check['baseline']!r} does "
                f"not match the frozen baseline condition "
                f"{baseline_status[cid]!r} (changed inputs invalidate "
                f"comparison)"
            )
        if check.get("after") not in CHECK_STATUSES:
            errors.append(
                f"check {cid!r}: 'after' must be one of "
                f"{list(CHECK_STATUSES)}, got {check.get('after')!r}"
            )
        if check.get("check_kind") not in CHECK_KINDS:
            errors.append(
                f"check {cid!r}: 'check_kind' must be one of "
                f"{list(CHECK_KINDS)} (manual review stays distinct from "
                f"deterministic tests)"
            )
        if not check.get("evidence"):
            errors.append(
                f"check {cid!r}: missing 'evidence' (a claimed outcome "
                f"without checks is rejected)"
            )
    if set(seen) != set(acceptance_ids):
        errors.append(
            f"result check IDs must equal the frozen acceptance_ids "
            f"{acceptance_ids}; got {sorted(seen)} (missing checks are "
            f"'unknown', never silently dropped)"
        )


def _validate_attempt_artifacts(errors: list[str], record: dict) -> None:
    result = record.get("result")
    if result is None:
        return
    artifacts = result.get("artifacts", [])
    if not isinstance(artifacts, list):
        errors.append("'result.artifacts' must be a list")
        return
    if len(artifacts) > ATTEMPT_MAX_ARTIFACTS:
        errors.append(
            f"'result.artifacts' holds at most {ATTEMPT_MAX_ARTIFACTS}, "
            f"got {len(artifacts)}"
        )
    for art in artifacts:
        if not isinstance(art, dict):
            errors.append("each artifact must be an object")
            continue
        where = f"artifact {art.get('path', '?')!r}"
        path_err = _artifact_path_error(art.get("path"))
        if path_err:
            errors.append(f"{where}: {path_err}")
        if art.get("media") not in ATTEMPT_ARTIFACT_MEDIA:
            errors.append(
                f"{where}: 'media' must be one of "
                f"{list(ATTEMPT_ARTIFACT_MEDIA)}, got {art.get('media')!r}"
            )
        sha = art.get("sha256")
        if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
            errors.append(f"{where}: 'sha256' must be 64 lowercase hex")
        size = art.get("size")
        if (
            not isinstance(size, int)
            or isinstance(size, bool)
            or not 0 <= size <= ATTEMPT_MAX_ARTIFACT_BYTES
        ):
            errors.append(
                f"{where}: 'size' must be an int 0..{ATTEMPT_MAX_ARTIFACT_BYTES}"
            )
        prov = art.get("provenance")
        if not isinstance(prov, dict):
            errors.append(f"{where}: missing object 'provenance'")
        else:
            if not prov.get("produced_by"):
                errors.append(f"{where}: provenance needs 'produced_by'")
            if not _is_utc_z(prov.get("produced_at")):
                errors.append(
                    f"{where}: provenance 'produced_at' must be UTC ISO-8601 (Z)"
                )
            if not prov.get("host"):
                errors.append(f"{where}: provenance needs 'host'")
        text = art.get("captured_text")
        outside = art.get("bytes_outside_scope", False)
        if text is not None:
            if not isinstance(text, str):
                errors.append(f"{where}: 'captured_text' must be a string")
                continue
            raw = text.encode("utf-8")
            if len(raw) > ATTEMPT_MAX_ARTIFACT_BYTES:
                errors.append(
                    f"{where}: captured bytes exceed the allowed capture "
                    f"scope; preserve references+hashes only, never ingest "
                    f"a full private log"
                )
                continue
            if outside:
                errors.append(
                    f"{where}: cannot carry both 'captured_text' and "
                    f"'bytes_outside_scope'"
                )
            if hashlib.sha256(raw).hexdigest() != (sha or ""):
                errors.append(
                    f"{where}: 'sha256' does not match 'captured_text' bytes "
                    f"(records carry real captured bytes, not fabricated "
                    f"success)"
                )
            if size != len(raw):
                errors.append(
                    f"{where}: 'size' {size!r} does not match captured byte "
                    f"length {len(raw)}"
                )
            content_err = _artifact_content_error(text, media=art.get("media"))
            if content_err:
                errors.append(f"{where}: {content_err}")
        elif not outside:
            errors.append(
                f"{where}: either carry bounded 'captured_text' or set "
                f"'bytes_outside_scope' with preserved references+hashes"
            )


def _validate_attempt_decision(errors: list[str], record: dict) -> None:
    decision = record.get("decision")
    if decision is None:
        return
    if not isinstance(decision, dict):
        errors.append("'decision' must be an object")
        return
    if not isinstance(record.get("result"), dict):
        errors.append(
            "'decision' without 'result' is an early result: register the "
            "baseline first, then import results, then decide"
        )
        return
    outcome = decision.get("outcome")
    if outcome not in ATTEMPT_DECISIONS:
        errors.append(
            f"'decision.outcome' must be one of {list(ATTEMPT_DECISIONS)}, "
            f"got {outcome!r}"
        )
        return
    if not decision.get("rationale"):
        errors.append("'decision' needs a 'rationale'")
    if not isinstance(decision.get("evidence_refs"), list) or not decision.get(
        "evidence_refs"
    ):
        errors.append(
            "'decision.evidence_refs' must be a non-empty list of evidence refs"
        )
    if not decision.get("reviewer"):
        errors.append(
            "'decision' needs a 'reviewer' (named reviewer/authority "
            "provenance; a JSON boolean is never human consent)"
        )
    auth = decision.get("authority")
    if not isinstance(auth, dict) or not auth.get("source"):
        errors.append("'decision.authority' must name its 'source'")
    elif auth.get("status") not in AUTHORITY_STATUSES:
        errors.append(
            f"'decision.authority.status' must be one of "
            f"{list(AUTHORITY_STATUSES)}, got {auth.get('status')!r}"
        )
    if not _is_utc_z(decision.get("decided_at")):
        errors.append("'decision.decided_at' must be a UTC ISO-8601 timestamp (Z)")
    else:
        result_at = _parse_utc(record["result"].get("observed_at"))
        decided_at = _parse_utc(decision.get("decided_at"))
        if result_at is not None and decided_at is not None and decided_at < result_at:
            errors.append(
                "'decision.decided_at' predates 'result.observed_at': "
                "backdating is rejected, record the actual decision time"
            )
    gate = decision.get("manual_review")
    if not isinstance(gate, dict) or not isinstance(gate.get("required"), bool):
        errors.append(
            "'decision.manual_review' must be an object with boolean 'required'"
        )
        gate = {}
    unknowns = decision.get("unresolved_unknowns", [])
    if not isinstance(unknowns, list):
        errors.append("'decision.unresolved_unknowns' must be a list")
        unknowns = []
    checks = record["result"].get("checks", [])
    checks = checks if isinstance(checks, list) else []
    unknown_checks = [
        c.get("id") for c in checks if isinstance(c, dict) and c.get("after") == "unknown"
    ]
    failed_checks = [
        c.get("id") for c in checks if isinstance(c, dict) and c.get("after") == "fail"
    ]
    unreviewed_human = [
        c.get("id")
        for c in checks
        if isinstance(c, dict)
        and c.get("after") == "review_required"
        and not (c.get("reviewed_by") and c.get("checked_at"))
    ]
    human_without_evidence = [
        c.get("id")
        for c in checks
        if isinstance(c, dict)
        and c.get("check_kind") == "human_review"
        and c.get("after") in ("pass", "fail")
        and not (c.get("reviewed_by") and c.get("checked_at"))
    ]
    protected = decision.get("protected_check", {})
    protected_passed = isinstance(protected, dict) and protected.get("passed") is True
    counterexample_kept = decision.get("counterexample_preserved") is True
    if outcome == "keep":
        if unknown_checks:
            errors.append(
                f"a 'keep' cannot be claimed from unknown checks "
                f"{unknown_checks} without reviewed evidence "
                f"(missing checks are 'unknown', never success)"
            )
        if unreviewed_human:
            errors.append(
                f"a 'keep' cannot be claimed from human-required checks "
                f"{unreviewed_human} without reviewed evidence "
                f"('reviewed_by' + 'checked_at')"
            )
        if human_without_evidence:
            errors.append(
                f"human-review checks {human_without_evidence} record a "
                f"deterministic outcome without a named review: manual review "
                f"stays distinct from deterministic tests"
            )
        if failed_checks:
            errors.append(
                f"a 'keep' cannot be claimed while checks fail "
                f"{failed_checks} (a claimed success without passing checks "
                f"is rejected)"
            )
        if not protected_passed:
            errors.append(
                "a 'keep' requires 'decision.protected_check.passed: true' "
                "(failed protected behavior prevents keep)"
            )
        if not counterexample_kept:
            errors.append(
                "a 'keep' requires 'decision.counterexample_preserved: true' "
                "(the good counterexample must survive the loop)"
            )
        if unknowns:
            errors.append(
                f"a 'keep' leaves no unresolved unknowns; got {unknowns} "
                f"(choose revise/discard/inconclusive until they resolve)"
            )
        if record["result"].get("inputs_changed") is True:
            errors.append(
                "inputs changed between baseline and result: the comparison "
                "is invalid — re-baseline as a new attempt, never keep"
            )
        if not gate.get("required"):
            errors.append(
                "a 'keep' needs an explicit pending manual review "
                "('decision.manual_review.required' must be true: a JSON "
                "boolean alone is never human consent)"
            )
        else:
            if not gate.get("reviewer") or not gate.get("checked_at") or not gate.get(
                "note"
            ):
                errors.append(
                    "a 'keep' needs manual-review provenance: 'reviewer', "
                    "'checked_at', and 'note' (who reviewed, when, what they "
                    "checked)"
                )
            else:
                checked = _parse_utc(gate.get("checked_at"))
                if (
                    result_at is not None
                    and checked is not None
                    and checked < result_at
                ):
                    errors.append(
                        "'decision.manual_review.checked_at' predates the "
                        "result: review must follow the evidence"
                    )


def _validate_attempt_followup(errors: list[str], record: dict) -> None:
    followup = record.get("followup")
    if followup is None:
        return
    if not isinstance(followup, dict):
        errors.append("'followup' must be an object")
        return
    if not isinstance(record.get("decision"), dict):
        errors.append(
            "'followup' without 'decision' is dangling: decide first, then "
            "record fresh use"
        )
        return
    fresh = followup.get("fresh_packet_id")
    if not isinstance(fresh, str) or not fresh:
        errors.append("'followup.fresh_packet_id' must be a non-empty string")
    elif fresh == record["baseline"].get("packet_id"):
        errors.append(
            "'followup.fresh_packet_id' must differ from the baseline packet: "
            "fresh use is distinct from the first post-test contact"
        )
    if not _is_utc_z(followup.get("observed_at")):
        errors.append("'followup.observed_at' must be a UTC ISO-8601 timestamp (Z)")
    else:
        decided_at = _parse_utc(record["decision"].get("decided_at"))
        fresh_at = _parse_utc(followup.get("observed_at"))
        if decided_at is not None and fresh_at is not None and fresh_at < decided_at:
            errors.append(
                "'followup.observed_at' predates 'decision.decided_at': "
                "backdating is rejected"
            )
    if not followup.get("note"):
        errors.append("'followup' needs a 'note' describing the fresh use")
    if record["decision"].get("outcome") == "discard" and not (
        followup.get("reopens") and followup.get("new_evidence")
    ):
        errors.append(
            "a discarded idea stays dropped unless the followup carries an "
            "explicit 'reopens' link plus 'new_evidence' changing its basis"
        )


def validate_attempt(record: object, expect_stage: str | None = None) -> list[str]:
    """Validate an attempt record's shape and lifecycle rules.

    Shape plus ordering/consistency only: passing never establishes that the
    experiment was worthwhile, authorized, or correctly executed. Reference
    checks against packets/contracts need check_attempt_refs().
    """
    errors: list[str] = []
    if not isinstance(record, dict):
        return ["top level must be an object"]
    if record.get("schema") != ATTEMPT_SCHEMA:
        errors.append(
            f"expected schema {ATTEMPT_SCHEMA!r}, got {record.get('schema')!r}"
        )
    attempt_id = record.get("attempt_id")
    if not isinstance(attempt_id, str) or not attempt_id:
        errors.append("'attempt_id' must be a non-empty string")
    elif not ID_RE.match(attempt_id):
        errors.append(
            f"'attempt_id' {attempt_id!r} is not a safe identifier "
            f"(letters/digits/_/./-, leading alnum)"
        )
    stage = record.get("stage")
    if stage not in ATTEMPT_STAGES:
        errors.append(
            f"'stage' must be one of {list(ATTEMPT_STAGES)}, got {stage!r}"
        )
        return errors
    if expect_stage is not None and stage != expect_stage:
        errors.append(
            f"expected stage {expect_stage!r} for this action, got {stage!r}"
        )
    if not _is_utc_z(record.get("started_at")):
        errors.append("'started_at' must be a UTC ISO-8601 timestamp (Z)")
    working = record.get("working_object")
    if not isinstance(working, dict) or not working.get("id"):
        errors.append("'working_object' must be an object with non-empty 'id'")
    hypothesis = record.get("hypothesis")
    if not isinstance(hypothesis, str) or not hypothesis:
        errors.append(
            "missing 'hypothesis': register the hypothesis before results "
            "arrive (a changed hypothesis starts a new attempt)"
        )
    contract = record.get("contract")
    acceptance_ids: list[str] = []
    if not isinstance(contract, dict):
        errors.append(
            "'contract' must be an object freezing the immutable contract "
            "snapshot/hash before results"
        )
    else:
        if not contract.get("contract_id"):
            errors.append("'contract.contract_id' must be non-empty")
        sha = contract.get("sha256")
        if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
            errors.append("'contract.sha256' must be 64 lowercase hex")
        ids = contract.get("acceptance_ids")
        if (
            not isinstance(ids, list)
            or not ids
            or not all(isinstance(i, str) and i for i in ids)
            or len(set(ids)) != len(ids)
        ):
            errors.append(
                "'contract.acceptance_ids' must be a non-empty list of unique "
                "condition IDs frozen before results"
            )
        else:
            acceptance_ids = list(ids)
        if contract.get("hypothesis") != hypothesis:
            errors.append(
                "'contract.hypothesis' must equal the attempt hypothesis: a "
                "changed hypothesis starts a new attempt, never an edit"
            )
    baseline = record.get("baseline")
    if not isinstance(baseline, dict):
        errors.append(
            "'baseline' must be an object freezing baseline input/output refs "
            "and acceptance condition IDs"
        )
    else:
        if not isinstance(baseline.get("packet_id"), str) or not baseline.get(
            "packet_id"
        ):
            errors.append("'baseline.packet_id' must be a non-empty string")
        if not _is_utc_z(baseline.get("observed_at")):
            errors.append("'baseline.observed_at' must be UTC ISO-8601 (Z)")
        else:
            started = _parse_utc(record.get("started_at"))
            observed = _parse_utc(baseline.get("observed_at"))
            if started is not None and observed is not None and observed < started:
                errors.append(
                    "'baseline.observed_at' predates 'started_at': backdating "
                    "is rejected"
                )
        for key in ("input_refs", "output_refs"):
            refs = baseline.get(key, [])
            if not isinstance(refs, list):
                errors.append(f"'baseline.{key}' must be a list")
            else:
                for ref in refs:
                    if not isinstance(ref, dict) or not ref.get("ref"):
                        errors.append(
                            f"'baseline.{key}' entries need a non-empty 'ref'"
                        )
    auth = record.get("authority")
    if not isinstance(auth, dict) or not auth.get("source"):
        errors.append(
            "'authority' must be an object naming its exact 'source' "
            "(record authority source/status without claiming a JSON "
            "boolean is human consent)"
        )
    else:
        if auth.get("status") not in AUTHORITY_STATUSES:
            errors.append(
                f"'authority.status' must be one of "
                f"{list(AUTHORITY_STATUSES)}, got {auth.get('status')!r}"
            )
        if not auth.get("reviewer"):
            errors.append("'authority' needs a 'reviewer' provenance")
    if not record.get("protected_behavior"):
        errors.append("missing 'protected_behavior' (preserved from the contract)")
    if not record.get("counterexample"):
        errors.append("missing 'counterexample' (the good counterexample is kept)")
    result = record.get("result")
    if result is not None:
        if not isinstance(result, dict):
            errors.append("'result' must be an object")
        else:
            if not _is_utc_z(result.get("observed_at")):
                errors.append("'result.observed_at' must be UTC ISO-8601 (Z)")
            else:
                baseline_at = _parse_utc(
                    baseline.get("observed_at") if isinstance(baseline, dict) else None
                )
                result_at = _parse_utc(result.get("observed_at"))
                if (
                    baseline_at is not None
                    and result_at is not None
                    and result_at < baseline_at
                ):
                    errors.append(
                        "'result.observed_at' predates 'baseline.observed_at': "
                        "results arrive after the baseline, never before"
                    )
            if not result.get("host"):
                errors.append("'result.host' must name the host that ran it")
            for key in ("revisions", "deployed_refs", "failures"):
                if key in result and not isinstance(result[key], list):
                    errors.append(f"'result.{key}' must be a list")
            for rev in result.get("revisions", []):
                if not isinstance(rev, dict) or not rev.get("repo") or not rev.get(
                    "rev"
                ):
                    errors.append(
                        "'result.revisions' entries need 'repo' and 'rev'"
                    )
            costs = result.get("costs")
            if not isinstance(costs, dict) or not costs.get("time") or not costs.get(
                "cost"
            ):
                errors.append(
                    "'result.costs' must name time and cost where observed "
                    "(use 'none observed' rather than omitting)"
                )
    if isinstance(baseline, dict) and acceptance_ids:
        _validate_attempt_checks(errors, record, acceptance_ids)
    _validate_attempt_artifacts(errors, record)
    _validate_attempt_decision(errors, record)
    _validate_attempt_followup(errors, record)
    for hit in _walk_secret_keys(record):
        errors.append(
            f"metadata field {hit!r} is secret/env/process-dump shaped: "
            f"attempt records must exclude secrets (redaction of arbitrary "
            f"free text is not guaranteed, so never put it here)"
        )
    # Stage gating: each manual action owns exactly one stage shape.
    has_result = isinstance(record.get("result"), dict)
    has_decision = isinstance(record.get("decision"), dict)
    has_followup = isinstance(record.get("followup"), dict)
    if stage == "started" and (has_result or has_decision or has_followup):
        errors.append(
            "stage 'started' registers hypothesis, contract snapshot, and "
            "baseline only: early results are rejected, register the "
            "baseline before output"
        )
    elif stage == "result" and (has_decision or has_followup):
        errors.append(
            "stage 'result' imports evidence only: decide separately after "
            "review, never in the same record"
        )
    elif stage == "decided" and has_followup:
        errors.append(
            "stage 'decided' records the decision only: fresh use belongs to "
            "a followup record"
        )
    if stage in ("result", "decided", "followed_up") and not has_result:
        errors.append(
            f"stage {stage!r} needs 'result': results arrive after the "
            f"baseline, never before it"
        )
    if stage in ("decided", "followed_up") and not has_decision:
        errors.append(f"stage {stage!r} needs 'decision'")
    if stage == "followed_up" and not has_followup:
        errors.append("stage 'followed_up' needs 'followup'")
    return errors


def _attempt_cited_refs(record: dict) -> tuple[set[str], set[str]]:
    """Collect cited packet source/observation IDs from checks and decisions."""
    sections = [
        record.get("result", {}).get("checks", []),
        record.get("decision", {}).get("evidence_refs", []),
    ]
    return _cited_refs(sections)


def check_attempt_refs(
    record: dict,
    *,
    packet: dict | None = None,
    after_packet: dict | None = None,
    fresh_packet: dict | None = None,
    contract: dict | None = None,
    prior: dict | None = None,
    artifact_root: str | Path | None = None,
) -> list[str]:
    """Cross-check an attempt against linked packets/contracts/prior attempts."""
    errors: list[str] = []
    supplied = [
        ("--packet", packet),
        ("--after-packet", after_packet),
        ("--fresh-packet", fresh_packet),
    ]
    union_sources: set[str] = set()
    union_obs: set[str] = set()
    for flag, pack in supplied:
        if pack is None:
            continue
        problems = validate_packet(pack)
        if problems:
            errors.append(f"{flag} is not a valid research-state packet: {problems[0]}")
            continue
        index = _packet_ref_index(pack)
        if index is None:
            errors.append(f"{flag} packet has no usable sources/observations")
            continue
        sources, obs_by_id = index
        union_sources |= sources
        union_obs |= set(obs_by_id)
    if packet is not None and validate_packet(packet) == []:
        if record.get("baseline", {}).get("packet_id") != packet.get("packet_id"):
            errors.append(
                f"baseline.packet_id {record.get('baseline', {}).get('packet_id')!r} "
                f"does not match --packet {packet.get('packet_id')!r}: a changed "
                f"baseline invalidates comparison, re-link to a fresh packet"
            )
    result = record.get("result") if isinstance(record.get("result"), dict) else {}
    if after_packet is not None and validate_packet(after_packet) == []:
        if result.get("packet_id") and result.get("packet_id") != after_packet.get(
            "packet_id"
        ):
            errors.append(
                f"result.packet_id {result.get('packet_id')!r} does not match "
                f"--after-packet {after_packet.get('packet_id')!r}"
            )
        after_at = _parse_utc(after_packet.get("collected_at"))
        result_at = _parse_utc(result.get("observed_at"))
        if after_at is not None and result_at is not None and after_at < result_at:
            errors.append(
                "--after-packet was collected before result.observed_at: "
                "post-experiment evidence must follow the result"
            )
    followup = record.get("followup") if isinstance(record.get("followup"), dict) else {}
    if fresh_packet is not None and validate_packet(fresh_packet) == []:
        if followup.get("fresh_packet_id") and followup.get(
            "fresh_packet_id"
        ) != fresh_packet.get("packet_id"):
            errors.append(
                f"followup.fresh_packet_id {followup.get('fresh_packet_id')!r} "
                f"does not match --fresh-packet {fresh_packet.get('packet_id')!r}"
            )
        if fresh_packet.get("packet_id") == record.get("baseline", {}).get("packet_id"):
            errors.append(
                "--fresh-packet repeats the baseline packet: fresh use needs "
                "a fresh packet, not the first post-test contact"
            )
    if union_sources or union_obs:
        cited_sources, cited_obs = _attempt_cited_refs(record)
        for sid in sorted(cited_sources):
            if sid not in union_sources:
                errors.append(
                    f"dangling source ref {sid!r} (names no supplied packet source)"
                )
        for oid in sorted(cited_obs):
            if oid not in union_obs:
                errors.append(
                    f"dangling observation ref {oid!r} (names no supplied "
                    f"packet observation)"
                )
    if contract is not None:
        if not isinstance(contract, dict):
            errors.append("--contract file is not a JSON object")
        else:
            shape = validate_contract(contract)
            if shape:
                errors.append(f"--contract is not shape-valid: {shape[0]}")
            else:
                digest = contract_canonical_hash(contract)
                if record.get("contract", {}).get("sha256") != digest:
                    errors.append(
                        "contract snapshot hash mismatch: the contract changed "
                        "since the baseline froze it — a changed contract "
                        "invalidates comparison, start a new attempt"
                    )
                live_ids = sorted(
                    a.get("id") for a in contract.get("acceptance", []) if a.get("id")
                )
                frozen = sorted(record.get("contract", {}).get("acceptance_ids", []))
                if live_ids != frozen:
                    errors.append(
                        f"contract acceptance IDs changed since baseline "
                        f"(live {live_ids} vs frozen {frozen}): start a new "
                        f"attempt, never backdate"
                    )
                if contract.get("hypothesis") != record.get("hypothesis"):
                    errors.append(
                        "contract hypothesis differs from the attempt "
                        "hypothesis: a changed hypothesis starts a new attempt"
                    )
    prior_valid = False
    if prior is not None:
        if not isinstance(prior, dict):
            errors.append("--prior file is not a JSON object")
        else:
            prior_expect = {
                "started": "started",
                "result": "started",
                "decided": "result",
                "followed_up": "decided",
            }.get(str(record.get("stage")))
            prior_errors = validate_attempt(prior, expect_stage=prior_expect)
            if prior_errors:
                errors.append(f"--prior is not a valid prior attempt: {prior_errors[0]}")
            else:
                prior_valid = True
                if prior.get("attempt_id") != record.get("attempt_id"):
                    errors.append(
                        f"--prior attempt {prior.get('attempt_id')!r} is a "
                        f"different lineage from {record.get('attempt_id')!r}: "
                        f"attempts are never overwritten, link explicitly"
                    )
                if prior.get("hypothesis") != record.get("hypothesis"):
                    errors.append(
                        "hypothesis changed since the prior record: start a "
                        "new attempt, never edit the frozen hypothesis"
                    )
                prior_contract = (
                    prior.get("contract")
                    if isinstance(prior.get("contract"), dict)
                    else {}
                )
                record_contract = (
                    record.get("contract")
                    if isinstance(record.get("contract"), dict)
                    else {}
                )
                if record_contract.get("sha256") != prior_contract.get("sha256"):
                    errors.append(
                        "contract snapshot hash changed since the prior record: "
                        "a new contract never silently replaces what --prior "
                        "recorded — start a new attempt"
                    )
                if record_contract.get("contract_id") != prior_contract.get(
                    "contract_id"
                ):
                    errors.append(
                        "contract id changed since the prior record: start a "
                        "new attempt, never edit the frozen contract"
                    )
                prior_ids = prior_contract.get("acceptance_ids")
                record_ids = record_contract.get("acceptance_ids")
                if sorted(prior_ids or []) != sorted(record_ids or []):
                    errors.append(
                        "contract acceptance definitions changed since the prior "
                        "record: start a new attempt, never edit frozen acceptance"
                    )
                if record_contract.get("hypothesis") != prior_contract.get(
                    "hypothesis"
                ):
                    errors.append(
                        "contract hypothesis changed since the prior record: "
                        "start a new attempt, never edit the frozen hypothesis"
                    )
                if record.get("baseline") != prior.get("baseline"):
                    errors.append(
                        "baseline changed since the prior record: the full "
                        "baseline (packet, refs, conditions) is frozen — "
                        "re-baseline only as a new attempt"
                    )
                frozen_sections = {
                    "result": ("result",),
                    "decided": ("result", "decision"),
                }.get(str(prior.get("stage")), ())
                for section in frozen_sections:
                    if record.get(section) != prior.get(section):
                        errors.append(
                            f"{section} changed since the prior record: prior "
                            f"stage payloads are frozen — advance lifecycle by "
                            f"adding the next section only"
                        )
                order = ("started", "result", "decided", "followed_up")
                if order.index(str(record.get("stage"))) < order.index(
                    str(prior.get("stage"))
                ) if prior.get("stage") in order and record.get("stage") in order else False:
                    errors.append(
                        f"stage {record.get('stage')!r} moves backwards from "
                        f"prior stage {prior.get('stage')!r}"
                    )

    def _latest_ts(rec: dict) -> datetime.datetime | None:
        candidates = [rec.get("started_at")]
        for section in ("result", "decision", "followup"):
            part = rec.get(section)
            if isinstance(part, dict):
                candidates.append(part.get("observed_at") or part.get("decided_at"))
        parsed = [_parse_utc(c) for c in candidates]
        parsed = [p for p in parsed if p is not None]
        return max(parsed) if parsed else None

    if prior_valid:
        old, new = _latest_ts(prior), _latest_ts(record)
        if old is not None and new is not None and new < old:
            errors.append(
                "record predates its --prior: manufactured timestamps and "
                "backdating are rejected"
            )
    if artifact_root is not None and result:
        root = Path(artifact_root)
        try:
            real_root = os.path.realpath(root)
        except OSError as exc:
            errors.append(f"--artifact-root is unreadable: {exc}")
            real_root = None
        if real_root is not None:
            for art in result.get("artifacts", []):
                if not isinstance(art, dict) or _artifact_path_error(art.get("path")):
                    continue
                candidate = os.path.realpath(os.path.join(real_root, str(art["path"])))
                if candidate != real_root and not candidate.startswith(real_root + os.sep):
                    errors.append(
                        f"artifact {art['path']!r} escapes --artifact-root "
                        f"(symlink/traversal rejected)"
                    )
                    continue
                if art.get("bytes_outside_scope", False) and art.get("captured_text") is None:
                    continue
                try:
                    with open(candidate, "rb") as handle:
                        raw = handle.read(ATTEMPT_MAX_ARTIFACT_BYTES + 1)
                except FileNotFoundError:
                    errors.append(
                        f"artifact {art['path']!r} not found under "
                        f"--artifact-root (dangling file ref rejected)"
                    )
                    continue
                except OSError as exc:
                    errors.append(
                        f"artifact {art['path']!r} unreadable: {exc}"
                    )
                    continue
                if len(raw) > ATTEMPT_MAX_ARTIFACT_BYTES:
                    errors.append(
                        f"artifact {art['path']!r} exceeds the allowed capture "
                        f"scope: preserve references+hashes only"
                    )
                    continue
                if hashlib.sha256(raw).hexdigest() != art.get("sha256"):
                    errors.append(
                        f"artifact {art['path']!r} hash mismatch: the record "
                        f"must carry real captured bytes, not fabricated success"
                    )
                    continue
                if art.get("size") != len(raw):
                    errors.append(
                        f"artifact {art['path']!r} size {art.get('size')!r} does "
                        f"not match file bytes {len(raw)}"
                    )
                    continue
                file_text = raw.decode("utf-8", errors="replace")
                file_content_err = _artifact_content_error(
                    file_text, media=art.get("media")
                )
                if file_content_err:
                    errors.append(
                        f"artifact {art['path']!r} {file_content_err}"
                    )
    return errors


def render_attempt_markdown(record: dict) -> str:
    """Render an attempt record as readable Markdown from the same facts."""
    working = record.get("working_object", {})
    contract = record.get("contract", {})
    baseline = record.get("baseline", {})
    result = record.get("result") if isinstance(record.get("result"), dict) else None
    decision = (
        record.get("decision") if isinstance(record.get("decision"), dict) else None
    )
    followup = (
        record.get("followup") if isinstance(record.get("followup"), dict) else None
    )
    lines = [
        f"# attempt {record.get('schema', '?')}",
        "",
        f"Attempt: `{record.get('attempt_id', '?')}`",
        f"Stage: `{record.get('stage', '?')}`",
        f"Started at: `{record.get('started_at', '?')}`",
        "",
        f"Working object: `{working.get('id', '?')}` — "
        f"{working.get('description', '')}",
        "",
        "## Hypothesis (frozen before results)",
        "",
        f"{record.get('hypothesis', '—')}",
        "",
        "## Contract snapshot (immutable hash)",
        "",
        f"Contract: `{contract.get('contract_id', '?')}` "
        f"(`{str(contract.get('sha256', '?'))[:16]}…`)",
        f"Acceptance IDs: {contract.get('acceptance_ids', [])}",
        "",
        "## Baseline",
        "",
        f"Packet: `{baseline.get('packet_id', '?')}` "
        f"at `{baseline.get('observed_at', '?')}`",
        "",
        "| condition | baseline |",
        "| --- | --- |",
    ]
    conds = baseline.get("conditions", []) if isinstance(baseline, dict) else []
    for cond in conds:
        if isinstance(cond, dict):
            lines.append(f"| `{cond.get('id', '?')}` | {cond.get('status', '?')} |")
    lines += [
        "",
        f"Protected behavior: {record.get('protected_behavior', '—')}",
        "",
        f"Counterexample: {record.get('counterexample', '—')}",
        "",
    ]
    if result is not None:
        lines += [
            "## Result (real evidence, observed after baseline)",
            "",
            f"Observed at: `{result.get('observed_at', '?')}` on "
            f"`{result.get('host', '?')}`",
            f"After packet: `{result.get('packet_id', '—')}`",
            f"Costs: time {result.get('costs', {}).get('time', '—')}; "
            f"cost {result.get('costs', {}).get('cost', '—')}",
            "",
            "| condition | baseline | after | check |",
            "| --- | --- | --- | --- |",
        ]
        for check in result.get("checks", []):
            if isinstance(check, dict):
                lines.append(
                    f"| `{check.get('id', '?')}` | {check.get('baseline', '?')} "
                    f"| {check.get('after', '?')} | {check.get('check_kind', '?')} |"
                )
        lines += ["", "### Artifacts (bounded, allowlisted, hashed)", ""]
        for art in result.get("artifacts", []):
            if isinstance(art, dict):
                lines.append(
                    f"- `{art.get('path', '?')}` ({art.get('media', '?')}, "
                    f"{art.get('size', '?')} bytes, "
                    f"`{str(art.get('sha256', '?'))[:16]}…`)"
                )
        if result.get("failures"):
            lines += ["", "### Failures (retained, not precedent)", ""]
            for failure in result["failures"]:
                lines.append(f"- {failure}")
        lines.append("")
    if decision is not None:
        gate = decision.get("manual_review", {})
        lines += [
            "## Decision",
            "",
            f"Outcome: `{decision.get('outcome', '?')}` by "
            f"`{decision.get('reviewer', '?')}` at "
            f"`{decision.get('decided_at', '?')}`",
            f"Authority: {decision.get('authority', {}).get('source', '?')} "
            f"({decision.get('authority', {}).get('status', '?')})",
            f"Manual review: required `{gate.get('required', '?')}` by "
            f"`{gate.get('reviewer', '—')}` — {gate.get('note', '')}",
            "",
            f"Rationale: {decision.get('rationale', '—')}",
            "",
        ]
    if followup is not None:
        lines += [
            "## Followup (fresh use, distinct from first post-test)",
            "",
            f"Fresh packet: `{followup.get('fresh_packet_id', '?')}` at "
            f"`{followup.get('observed_at', '?')}`",
            "",
            f"{followup.get('note', '—')}",
            "",
        ]
    lines += [
        "_Acceptance-check commands are recorded data and are never executed "
        "by this tool. A JSON boolean is never human consent: keep decisions "
        "require a named reviewer, timestamped review, and reviewed evidence. "
        "Failures stay attempt history; dropped ideas stay dropped without "
        "new evidence._",
        "",
    ]
    return "\n".join(lines)


def persist_attempt(record: dict, state_dir: Path) -> tuple[Path, Path]:
    """Persist an attempt record as immutable JSON + Markdown (private)."""
    ensure_private_dir(state_dir)
    base = "attempt-" + _record_stamp(
        record.get("started_at", ""), record.get("attempt_id", "")
    )
    json_path = state_dir / f"{base}.json"
    md_path = state_dir / f"{base}.md"
    atomic_write_private(
        json_path, (json.dumps(record, indent=2, sort_keys=True) + "\n").encode("utf-8")
    )
    atomic_write_private(md_path, render_attempt_markdown(record).encode("utf-8"))
    return json_path, md_path


def load_optional_record(path_arg: str | None, flag: str):
    """Load an optional JSON reference file, raising ValueError on failure."""
    if not path_arg:
        return None
    record = load_record_file(Path(path_arg))
    if not isinstance(record, dict):
        raise ValueError(f"{flag} file {path_arg}: top level must be an object")
    return record


def cmd_attempt_validate(args: argparse.Namespace) -> int:
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state attempt-validate: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
        after_packet = load_reference_packet(args.after_packet)
        fresh_packet = load_reference_packet(args.fresh_packet)
        contract = load_optional_record(args.contract, "--contract")
        prior = load_optional_record(args.prior, "--prior")
    except ValueError as exc:
        print(f"research-state attempt-validate: {exc}", file=sys.stderr)
        return 2
    errors = validate_attempt(record, expect_stage=args.expect_stage)
    errors.extend(
        check_attempt_refs(
            record,
            packet=packet,
            after_packet=after_packet,
            fresh_packet=fresh_packet,
            contract=contract,
            prior=prior,
            artifact_root=args.artifact_root,
        )
    )
    if errors:
        print(
            f"research-state attempt-validate: INVALID {record_path}",
            file=sys.stderr,
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print(
        f"research-state attempt-validate: OK {record_path} "
        f"(stage {record.get('stage', '?')} shape valid — NOT an approval)"
    )
    return 0


def cmd_attempt_stage(stage: str, args: argparse.Namespace) -> int:
    """Validate a stage-bound attempt record and persist it immutably."""
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state attempt-{stage.replace('_', '-')}: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
        after_packet = load_reference_packet(getattr(args, "after_packet", None))
        fresh_packet = load_reference_packet(getattr(args, "fresh_packet", None))
        contract = load_optional_record(getattr(args, "contract", None), "--contract")
        prior = load_optional_record(getattr(args, "prior", None), "--prior")
    except ValueError as exc:
        print(f"research-state attempt-{stage.replace('_', '-')}: {exc}", file=sys.stderr)
        return 2
    expect = {
        "start": "started",
        "import_result": "result",
        "decide": "decided",
        "followup": "followed_up",
    }[stage]
    errors = validate_attempt(record, expect_stage=expect)
    errors.extend(
        check_attempt_refs(
            record,
            packet=packet,
            after_packet=after_packet,
            fresh_packet=fresh_packet,
            contract=contract,
            prior=prior,
            artifact_root=getattr(args, "artifact_root", None),
        )
    )
    # Storage gating: persistence requires actual registered baseline/contract
    # references and (past start) a previously persisted prior record — never
    # self-asserted timestamps/shape alone. Shape-only `attempt-validate`
    # may omit them; storage actions must not.
    state_dir_for_gate = (
        Path(args.state_dir) if getattr(args, "state_dir", None) else _default_state_dir()
    )
    def _prior_under_state(prior_arg: str | None) -> bool:
        if not prior_arg:
            return False
        try:
            state_real = os.path.realpath(state_dir_for_gate)
            prior_real = os.path.realpath(prior_arg)
            return prior_real == state_real or prior_real.startswith(state_real + os.sep)
        except OSError:
            return False
    if stage == "start":
        if packet is None:
            errors.append(
                "attempt-start requires --packet: persistence needs the actual "
                "registered baseline packet reference (omitted refs rejected)"
            )
        if contract is None:
            errors.append(
                "attempt-start requires --contract: persistence needs the actual "
                "registered contract reference (omitted refs rejected)"
            )
    elif stage == "import_result":
        if packet is None:
            errors.append(
                "attempt-import-result requires --packet: persistence needs the "
                "actual registered baseline packet reference"
            )
        if after_packet is None:
            errors.append(
                "attempt-import-result requires --after-packet: persistence needs "
                "the actual post-experiment packet reference"
            )
        if contract is None:
            errors.append(
                "attempt-import-result requires --contract: persistence needs the "
                "actual registered contract reference"
            )
        if prior is None:
            errors.append(
                "attempt-import-result requires --prior: persistence needs a "
                "previously persisted started record (self-asserted "
                "timestamps/shape rejected)"
            )
        if getattr(args, "artifact_root", None) is None:
            errors.append(
                "attempt-import-result requires --artifact-root: persistence needs "
                "the artifact root holding the real captured bytes"
            )
        if prior is not None:
            if not isinstance(prior, dict) or prior.get("stage") != "started":
                errors.append(
                    "attempt-import-result requires --prior to be a previously "
                    "persisted started record (stage 'started' with the same "
                    "attempt_id)"
                )
            elif not _prior_under_state(getattr(args, "prior", None)):
                errors.append(
                    "attempt-import-result requires --prior to be a previously "
                    "persisted record under --state-dir (not an detached file)"
                )
    elif stage == "decide":
        if packet is None:
            errors.append("attempt-decide requires --packet (baseline reference)")
        if after_packet is None:
            errors.append("attempt-decide requires --after-packet (after reference)")
        if prior is None:
            errors.append("attempt-decide requires --prior (previously persisted result)")
        elif isinstance(prior, dict) and prior.get("stage") != "result":
            errors.append(
                "attempt-decide requires --prior to be a previously persisted "
                "result record (stage 'result')"
            )
        elif prior is not None and not _prior_under_state(getattr(args, "prior", None)):
            errors.append(
                "attempt-decide requires --prior under --state-dir (previously "
                "persisted, not a detached file)"
            )
    elif stage == "followup":
        if packet is None:
            errors.append("attempt-followup requires --packet (baseline reference)")
        if fresh_packet is None:
            errors.append(
                "attempt-followup requires --fresh-packet (fresh-use reference)"
            )
        if prior is None:
            errors.append(
                "attempt-followup requires --prior (previously persisted decision)"
            )
        elif isinstance(prior, dict) and prior.get("stage") != "decided":
            errors.append(
                "attempt-followup requires --prior to be a previously persisted "
                "decided record (stage 'decided')"
            )
        elif prior is not None and not _prior_under_state(getattr(args, "prior", None)):
            errors.append(
                "attempt-followup requires --prior under --state-dir (previously "
                "persisted, not a detached file)"
            )
    if errors:
        print(
            f"research-state attempt-{stage.replace('_', '-')}: "
            f"INVALID {record_path}",
            file=sys.stderr,
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    state_dir = Path(args.state_dir) if args.state_dir else _default_state_dir()
    try:
        json_path, md_path = persist_attempt(record, state_dir)
    except (OSError, FileExistsError) as exc:
        print(
            f"research-state attempt-{stage.replace('_', '-')}: cannot persist: "
            f"{exc}",
            file=sys.stderr,
        )
        return 1
    print(f"stored attempt {record['attempt_id']} stage {expect} -> {json_path}")
    print(f"rendered -> {md_path}")
    outcome = (record.get("decision") or {}).get("outcome") if isinstance(
        record.get("decision"), dict
    ) else None
    if outcome in ("discard", "inconclusive") or (
        isinstance(record.get("result"), dict)
        and any(
            isinstance(c, dict) and c.get("after") == "fail"
            for c in record["result"].get("checks", [])
        )
    ):
        print(
            "retained as attempt history, not successful precedent "
            "(failures stay attempts; dropped ideas stay dropped without "
            "new evidence)."
        )
    return 0


def _contains_score_key(value: object) -> bool:
    """True when any mapping key is 'score' or 'surprise_score' (forbidden)."""
    stack: list[object] = [value]
    while stack:
        current = stack.pop()
        if isinstance(current, dict):
            for key, item in current.items():
                if key in ("score", "surprise_score"):
                    return True
                stack.append(item)
        elif isinstance(current, list):
            stack.extend(current)
    return False


def validate_transfer(record: object) -> list[str]:
    """Validate a second-object transfer record shape. Empty list is valid.

    Shape only, never authorization: a valid transfer still needs its cited
    target packet, source attempt provenance, and operator judgment before
    anything runs. Rules enforced here:

    - source and target working objects are both named and DISTINCT (no
      hardcoded first-object names; any two ids work, but they must differ);
    - a failed/inconclusive source (discard/inconclusive) can never validate
      as ``adapted`` — failures remain history, not successful precedent;
    - a dropped (discard) source needs an explicit boolean ``reopens`` plus
      non-empty ``new_evidence`` to reopen; otherwise it stays dropped;
    - ``adapted`` needs every applicability check ``verified`` and no
      unverified interface; unknown target prerequisites force
      ``declined``/``insufficient_evidence``/``no_change``, never a blind copy;
    - ``no_change`` (no meaningful change) is legitimate with an explanatory
      ``note`` and no obligation to fill a cadence;
    - no ``score``/``surprise_score`` anywhere: surprise is a handoff, not a
      number.
    """
    errors: list[str] = []
    if not isinstance(record, dict):
        return ["top level must be an object"]
    if record.get("schema") != TRANSFER_SCHEMA:
        errors.append(
            f"expected schema {TRANSFER_SCHEMA!r}, got {record.get('schema')!r}"
        )
    if not isinstance(record.get("transfer_id"), str) or not record.get("transfer_id"):
        errors.append("'transfer_id' must be a non-empty string")
    if not _is_utc_z(record.get("created_at")):
        errors.append("'created_at' must be a UTC ISO-8601 timestamp (Z)")
    status = record.get("status")
    if status not in TRANSFER_STATUSES:
        errors.append(
            f"'status' must be one of {list(TRANSFER_STATUSES)}, got {status!r}"
        )
    source = record.get("source")
    if not isinstance(source, dict):
        errors.append("'source' must be an object (attempt provenance + constraints)")
        source = {}
    target = record.get("target")
    if not isinstance(target, dict):
        errors.append("'target' must be an object (second working object + packet)")
        target = {}
    for key in ("attempt_id", "packet_id"):
        if not isinstance(source.get(key), str) or not source.get(key):
            errors.append(f"'source.{key}' must be a non-empty string")
    decision = source.get("decision")
    if decision not in ATTEMPT_DECISIONS:
        errors.append(
            f"'source.decision' must be one of {list(ATTEMPT_DECISIONS)}, "
            f"got {decision!r} (failed/inconclusive sources stay history)"
        )
    src_working = source.get("working_object")
    if not isinstance(src_working, dict) or not src_working.get("id"):
        errors.append("'source.working_object' must be an object with non-empty 'id'")
    tgt_working = target.get("working_object")
    if not isinstance(tgt_working, dict) or not tgt_working.get("id"):
        errors.append("'target.working_object' must be an object with non-empty 'id'")
    if (
        isinstance(src_working, dict)
        and isinstance(tgt_working, dict)
        and src_working.get("id")
        and src_working.get("id") == tgt_working.get("id")
    ):
        errors.append(
            f"transfer needs a DISTINCT second working object: source "
            f"{src_working.get('id')!r} equals target (reuse the same "
            f"scope/packet/contract/attempt interfaces against an explicit "
            f"alternate scope, not the same object)"
        )
    if not isinstance(target.get("packet_id"), str) or not target.get("packet_id"):
        errors.append("'target.packet_id' must be a non-empty string (fresh packet)")
    relation = source.get("relation")
    if not isinstance(relation, dict) or not relation.get("description"):
        errors.append(
            "'source.relation' must be an object with non-empty 'description' "
            "(the previously demonstrated relation being transferred)"
        )
    elif not isinstance(relation.get("constraints", []), list):
        errors.append("'source.relation.constraints' must be a list when present")
    checks = record.get("applicability")
    if not isinstance(checks, list) or not checks:
        errors.append(
            "'applicability' must be a non-empty list (source status checked "
            "against the target before adapting or declining)"
        )
        checks = []
    else:
        for item in checks:
            if not isinstance(item, dict) or not item.get("id"):
                errors.append("each 'applicability' entry needs an object with 'id'")
                continue
            if item.get("status") not in PREREQ_STATUSES:
                errors.append(
                    f"applicability {item.get('id')!r}: status must be one of "
                    f"{list(PREREQ_STATUSES)}, got {item.get('status')!r}"
                )
    unverified = record.get("unverified_interface", False)
    if not isinstance(unverified, bool):
        errors.append("'unverified_interface' must be boolean when present")
        unverified = False
    if unverified and status == "adapted":
        errors.append(
            "transfer needs an unverified interface: return "
            "'declined'/'insufficient_evidence', never copy the first "
            "contract blindly as 'adapted'"
        )
    if decision in ("discard", "inconclusive") and status == "adapted":
        if not (record.get("reopens") is True and record.get("new_evidence")):
            errors.append(
                f"source decision {decision!r} cannot transfer as 'adapted' "
                f"without explicit reopen plus new evidence: "
                f"failed/inconclusive procedures remain attempt history, not "
                f"successful precedent (mere new cadence is not enough)"
            )
    if decision == "discard":
        if not isinstance(record.get("reopens"), bool):
            errors.append(
                "a dropped (discard) source needs an explicit boolean 'reopens': "
                "a dropped idea needs new evidence plus explicit reopen"
            )
        elif record.get("reopens") and not record.get("new_evidence"):
            errors.append(
                "reopening a dropped idea needs non-empty 'new_evidence': "
                "mere new cadence is not enough"
            )
    if status == "adapted":
        adaptation = record.get("adaptation")
        if not isinstance(adaptation, dict) or not adaptation.get("description"):
            errors.append(
                "status 'adapted' must carry 'adaptation' with non-empty "
                "'description' (how the relation was adapted to the target)"
            )
        if any(
            isinstance(item, dict) and item.get("status") != "verified"
            for item in checks
            if isinstance(item, dict)
        ):
            errors.append(
                "status 'adapted' needs every 'applicability' check 'verified': "
                "decline (with evidence) while target prerequisites are unknown"
            )
    elif status in ("declined", "insufficient_evidence"):
        decline = record.get("decline")
        if not isinstance(decline, dict) or not decline.get("reason"):
            errors.append(
                f"status {status!r} must carry 'decline' with non-empty 'reason' "
                f"(decline with evidence, not a blind copy)"
            )
        if status == "insufficient_evidence" and not any(
            isinstance(item, dict) and item.get("status") != "verified"
            for item in checks
            if isinstance(item, dict)
        ):
            errors.append(
                "status 'insufficient_evidence' must name at least one "
                "non-verified 'applicability' check (unknown prerequisites)"
            )
    elif status == "no_change":
        if not record.get("note"):
            errors.append(
                "status 'no_change' must carry a non-empty 'note': no meaningful "
                "change is a first-class result, explained, never a cadence "
                "obligation"
            )
    evidence = record.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        errors.append(
            "'evidence' must be a non-empty list (target-packet refs + "
            "descriptions, not reused first-object evidence)"
        )
    else:
        for item in evidence:
            if isinstance(item, str):
                if not item:
                    errors.append("'evidence' entries must be non-empty")
            elif isinstance(item, dict):
                if not (
                    item.get("description")
                    or item.get("observation_id")
                    or item.get("source_id")
                ):
                    errors.append(
                        "'evidence' entries need 'description' or a packet ref"
                    )
            else:
                errors.append("'evidence' entries must be strings or objects")
    later = record.get("later_contact", {"status": "pending"})
    if not isinstance(later, dict):
        errors.append("'later_contact' must be an object when present")
    elif later.get("status") not in LATER_CONTACT_STATUSES:
        errors.append(
            f"'later_contact.status' must be one of "
            f"{list(LATER_CONTACT_STATUSES)}, got {later.get('status')!r} "
            f"(later confirming/contradicting contact, not a score)"
        )
    elif later.get("status") in ("confirmed", "contradicted") and not (
        later.get("packet_id") or later.get("note")
    ):
        errors.append(
            f"later_contact {later.get('status')!r} needs 'packet_id' or 'note' "
            f"(what later contact confirmed or contradicted)"
        )
    if _contains_score_key(record):
        errors.append(
            "transfer must not compute a surprise/salience score: "
            "'score'/'surprise_score' keys are forbidden"
        )
    return errors


def check_transfer_refs(
    record: dict,
    *,
    packet: dict | None,
    prior: dict | None,
) -> list[str]:
    """Check transfer refs: target evidence against the target packet, source
    provenance against the supplied source attempt."""
    errors: list[str] = []
    target = record.get("target", {}) if isinstance(record.get("target"), dict) else {}
    source = record.get("source", {}) if isinstance(record.get("source"), dict) else {}
    if packet is not None:
        if packet.get("packet_id") != target.get("packet_id"):
            errors.append(
                f"transfer: target.packet_id {target.get('packet_id')!r} does not "
                f"match reference packet {packet.get('packet_id')!r}; re-link "
                f"to a fresh packet"
            )
        else:
            _check_refs_against_packet(
                errors,
                "transfer",
                [
                    record.get("evidence"),
                    record.get("applicability"),
                    record.get("target"),
                ],
                packet,
                target.get("packet_id", ""),
            )
    if prior is not None:
        if not isinstance(prior, dict):
            errors.append("transfer: --prior attempt is not an object")
        else:
            if prior.get("attempt_id") != source.get("attempt_id"):
                errors.append(
                    f"transfer: source.attempt_id {source.get('attempt_id')!r} "
                    f"does not match --prior attempt "
                    f"{prior.get('attempt_id')!r} (source provenance)"
                )
            if prior.get("decision") is not None:
                prior_decision = prior.get("decision")
                if isinstance(prior_decision, dict):
                    prior_decision = prior_decision.get(
                        "decision", prior_decision.get("outcome", prior_decision)
                    )
                if prior_decision != source.get("decision"):
                    errors.append(
                        f"transfer: source.decision {source.get('decision')!r} "
                        f"does not match --prior decision "
                        f"{prior_decision!r}; check source status, never "
                        f"masquerade a failure as precedent"
                    )
            prior_working = prior.get("working_object", {})
            src_working_id = (
                source.get("working_object", {}).get("id")
                if isinstance(source.get("working_object"), dict)
                else None
            )
            if (
                isinstance(prior_working, dict)
                and prior_working.get("id")
                and src_working_id
                and prior_working.get("id") != src_working_id
            ):
                errors.append(
                    f"transfer: source working object {src_working_id!r} does not "
                    f"match --prior working object "
                    f"{prior_working.get('id')!r}"
                )
    return errors


def render_transfer_markdown(record: dict) -> str:
    """Render a transfer record as readable Markdown from the same facts."""
    source = record.get("source", {})
    target = record.get("target", {})
    src_working = source.get("working_object", {})
    tgt_working = target.get("working_object", {})
    relation = source.get("relation", {})
    later = record.get("later_contact", {})
    lines = [
        f"# transfer {record.get('schema', '?')}",
        "",
        f"Transfer: `{record.get('transfer_id', '?')}`",
        f"Created at: `{record.get('created_at', '?')}`",
        f"Status: `{record.get('status', '?')}` "
        "(adapted | declined | insufficient_evidence | no_change)",
        "",
        f"Source object: `{src_working.get('id', '?')}` — "
        f"{src_working.get('description', '')}",
        f"Source attempt: `{source.get('attempt_id', '?')}` "
        f"(decision `{source.get('decision', '?')}`, packet "
        f"`{source.get('packet_id', '?')}`)",
        f"Target object: `{tgt_working.get('id', '?')}` — "
        f"{tgt_working.get('description', '')}",
        f"Target packet: `{target.get('packet_id', '?')}`",
        "",
        "## Transferred relation (source constraints)",
        "",
        f"{relation.get('description', '—') if isinstance(relation, dict) else '—'}",
        "",
    ]
    constraints = relation.get("constraints", []) if isinstance(relation, dict) else []
    if constraints:
        lines += ["Constraints carried:", ""]
        for item in constraints:
            lines.append(f"- {item}")
        lines.append("")
    lines += ["## Applicability to target", ""]
    for item in record.get("applicability", []):
        if isinstance(item, dict):
            lines.append(
                f"- `{item.get('id', '?')}` ({item.get('status', '?')}) — "
                f"{item.get('description', '')}"
            )
        else:
            lines.append(f"- {item}")
    lines.append("")
    if record.get("adaptation"):
        adaptation = record["adaptation"]
        lines += [
            "## Adaptation",
            "",
            f"{adaptation.get('description', '—') if isinstance(adaptation, dict) else adaptation}",
            "",
        ]
    if record.get("decline"):
        decline = record["decline"]
        lines += [
            "## Decline (with evidence)",
            "",
            f"{decline.get('reason', '—') if isinstance(decline, dict) else decline}",
            "",
        ]
    if record.get("note"):
        lines += ["## Note (no meaningful change is legitimate)", "", f"{record['note']}", ""]
    if record.get("reopens"):
        lines += ["## Reopen", "", f"Reopens dropped idea with new evidence: {record.get('new_evidence', [])}", ""]
    lines += ["## Evidence (target packet, not reused source evidence)", ""]
    for item in record.get("evidence", []):
        if isinstance(item, str):
            lines.append(f"- {item}")
        else:
            ref = item.get("observation_id") or item.get("source_id") or "—"
            lines.append(f"- `{ref}` — {item.get('description', '')}")
    lines += [
        "",
        "## Later contact",
        "",
        f"Status: `{later.get('status', '?') if isinstance(later, dict) else '?'}`"
        + (
            f" — packet `{later.get('packet_id', '')}` {later.get('note', '')}"
            if isinstance(later, dict) and (later.get("packet_id") or later.get("note"))
            else " (pending: confirming/contradicting contact still owed)"
        ),
        "",
        "_Failed/inconclusive sources stay history. Unknown target "
        "prerequisites force decline, never a blind copy. No score._",
        "",
    ]
    return "\n".join(lines)


def persist_transfer(record: dict, state_dir: Path) -> tuple[Path, Path]:
    """Persist a transfer record as immutable JSON + Markdown (private)."""
    ensure_private_dir(state_dir)
    base = "transfer-" + _record_stamp(
        record.get("created_at", ""), record.get("transfer_id", "")
    )
    json_path = state_dir / f"{base}.json"
    md_path = state_dir / f"{base}.md"
    atomic_write_private(
        json_path, (json.dumps(record, indent=2, sort_keys=True) + "\n").encode("utf-8")
    )
    atomic_write_private(md_path, render_transfer_markdown(record).encode("utf-8"))
    return json_path, md_path


def validate_surprise(record: object) -> list[str]:
    """Validate an optional useful-surprise operator handoff. Empty is valid.

    An unasked connection is surfaced for the operator to recognize or
    reject; the handoff records what surfaced, why now, the operator call,
    and later confirming/contradicting contact. Recognition is never inferred
    from absence of complaint, and surprise is never scored.
    """
    errors: list[str] = []
    if not isinstance(record, dict):
        return ["top level must be an object"]
    if record.get("schema") != SURPRISE_SCHEMA:
        errors.append(
            f"expected schema {SURPRISE_SCHEMA!r}, got {record.get('schema')!r}"
        )
    if not isinstance(record.get("surprise_id"), str) or not record.get("surprise_id"):
        errors.append("'surprise_id' must be a non-empty string")
    if not _is_utc_z(record.get("created_at")):
        errors.append("'created_at' must be a UTC ISO-8601 timestamp (Z)")
    working = record.get("working_object")
    if not isinstance(working, dict) or not working.get("id"):
        errors.append("'working_object' must be an object with non-empty 'id'")
    if not isinstance(record.get("packet_id"), str) or not record.get("packet_id"):
        errors.append("'packet_id' must be a non-empty string (the linked packet)")
    connection = record.get("connection")
    if not isinstance(connection, dict):
        errors.append(
            "'connection' must be an object (the unasked connection surfaced)"
        )
    else:
        if not connection.get("description"):
            errors.append("'connection.description' must be non-empty (what surfaced)")
        if not connection.get("why_now"):
            errors.append(
                "'connection.why_now' must be non-empty (why this moment, not "
                "a cadence fill)"
            )
    operator = record.get("operator")
    if not isinstance(operator, dict):
        errors.append("'operator' must be an object (the operator call)")
    elif operator.get("status") not in SURPRISE_OPERATOR_STATUSES:
        errors.append(
            f"'operator.status' must be one of "
            f"{list(SURPRISE_OPERATOR_STATUSES)}, got {operator.get('status')!r} "
            f"(recognized/rejected/unknown only; never infer recognition "
            f"from silence)"
        )
    later = record.get("later_contact", {"status": "pending"})
    if not isinstance(later, dict):
        errors.append("'later_contact' must be an object when present")
    elif later.get("status") not in LATER_CONTACT_STATUSES:
        errors.append(
            f"'later_contact.status' must be one of "
            f"{list(LATER_CONTACT_STATUSES)}, got {later.get('status')!r}"
        )
    elif later.get("status") in ("confirmed", "contradicted") and not (
        later.get("packet_id") or later.get("note")
    ):
        errors.append(
            f"later_contact {later.get('status')!r} needs 'packet_id' or 'note'"
        )
    if _contains_score_key(record):
        errors.append(
            "surprise is a handoff, not a number: "
            "'score'/'surprise_score' keys are forbidden"
        )
    return errors


def check_surprise_refs(record: dict, packet: dict) -> list[str]:
    """Reject surprise refs that match no packet (re-link to a fresh packet)."""
    errors: list[str] = []
    _check_refs_against_packet(
        errors,
        "surprise",
        [record.get("connection"), record.get("working_object")],
        packet,
        record.get("packet_id", ""),
    )
    return errors


def render_surprise_markdown(record: dict) -> str:
    """Render a surprise handoff as readable Markdown from the same facts."""
    working = record.get("working_object", {})
    connection = record.get("connection", {})
    operator = record.get("operator", {})
    later = record.get("later_contact", {})
    lines = [
        f"# useful surprise {record.get('schema', '?')}",
        "",
        f"Surprise: `{record.get('surprise_id', '?')}`",
        f"Created at: `{record.get('created_at', '?')}`",
        f"Working object: `{working.get('id', '?')}` — "
        f"{working.get('description', '')}",
        f"Packet: `{record.get('packet_id', '?')}`",
        "",
        "## Unasked connection surfaced",
        "",
        f"{connection.get('description', '—') if isinstance(connection, dict) else connection}",
        "",
        "## Why now",
        "",
        f"{connection.get('why_now', '—') if isinstance(connection, dict) else '—'}",
        "",
        "## Operator call",
        "",
        f"Status: `{operator.get('status', '?') if isinstance(operator, dict) else '?'}`"
        " (recognized | rejected | unknown — silence is unknown, never "
        "recognition)",
        "",
        "## Later contact",
        "",
        f"Status: `{later.get('status', '?') if isinstance(later, dict) else '?'}`"
        + (
            f" — packet `{later.get('packet_id', '')}` {later.get('note', '')}"
            if isinstance(later, dict) and (later.get("packet_id") or later.get("note"))
            else " (pending: confirming/contradicting contact still owed)"
        ),
        "",
        "_Surprise itself is not a score._",
        "",
    ]
    return "\n".join(lines)


def persist_surprise(record: dict, state_dir: Path) -> tuple[Path, Path]:
    """Persist a surprise handoff as immutable JSON + Markdown (private)."""
    ensure_private_dir(state_dir)
    base = "surprise-" + _record_stamp(
        record.get("created_at", ""), record.get("surprise_id", "")
    )
    json_path = state_dir / f"{base}.json"
    md_path = state_dir / f"{base}.md"
    atomic_write_private(
        json_path, (json.dumps(record, indent=2, sort_keys=True) + "\n").encode("utf-8")
    )
    atomic_write_private(md_path, render_surprise_markdown(record).encode("utf-8"))
    return json_path, md_path


def cmd_transfer_validate(args: argparse.Namespace) -> int:
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state transfer-validate: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
        prior = load_optional_record(args.prior, "--prior")
    except ValueError as exc:
        print(f"research-state transfer-validate: {exc}", file=sys.stderr)
        return 2
    errors = validate_transfer(record)
    if packet is not None or prior is not None:
        errors.extend(
            check_transfer_refs(record, packet=packet, prior=prior)
        )
    if errors:
        print(
            f"research-state transfer-validate: INVALID {record_path}",
            file=sys.stderr,
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print(
        f"research-state transfer-validate: OK {record_path} "
        f"(shape valid — NOT an approval)"
    )
    return 0


def cmd_transfer_store(args: argparse.Namespace) -> int:
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state transfer-store: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
        prior = load_optional_record(args.prior, "--prior")
    except ValueError as exc:
        print(f"research-state transfer-store: {exc}", file=sys.stderr)
        return 2
    if packet is None or prior is None:
        print(
            "research-state transfer-store: --packet (target packet) and --prior "
            "(source attempt) are both required for provenance",
            file=sys.stderr,
        )
        return 2
    errors = validate_transfer(record)
    errors.extend(check_transfer_refs(record, packet=packet, prior=prior))
    if errors:
        print(
            f"research-state transfer-store: INVALID {record_path}", file=sys.stderr
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    state_dir = Path(args.state_dir) if args.state_dir else _default_state_dir()
    try:
        json_path, md_path = persist_transfer(record, state_dir)
    except (OSError, FileExistsError) as exc:
        print(f"research-state transfer-store: cannot persist: {exc}", file=sys.stderr)
        return 1
    print(f"stored {record['transfer_id']} -> {json_path}")
    print(f"rendered -> {md_path}")
    return 0


def cmd_surprise_validate(args: argparse.Namespace) -> int:
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state surprise-validate: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
    except ValueError as exc:
        print(f"research-state surprise-validate: {exc}", file=sys.stderr)
        return 2
    errors = validate_surprise(record)
    if packet is not None:
        errors.extend(check_surprise_refs(record, packet))
    if errors:
        print(
            f"research-state surprise-validate: INVALID {record_path}",
            file=sys.stderr,
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print(
        f"research-state surprise-validate: OK {record_path} "
        f"(shape valid — NOT an approval)"
    )
    return 0


def cmd_surprise_store(args: argparse.Namespace) -> int:
    record_path = Path(args.record or args.input)
    try:
        record = load_record_file(record_path)
    except ValueError as exc:
        print(f"research-state surprise-store: {exc}", file=sys.stderr)
        return 2
    try:
        packet = load_reference_packet(args.packet)
    except ValueError as exc:
        print(f"research-state surprise-store: {exc}", file=sys.stderr)
        return 2
    if packet is None:
        print(
            "research-state surprise-store: --packet is required for provenance",
            file=sys.stderr,
        )
        return 2
    errors = validate_surprise(record)
    errors.extend(check_surprise_refs(record, packet))
    if errors:
        print(
            f"research-state surprise-store: INVALID {record_path}", file=sys.stderr
        )
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    state_dir = Path(args.state_dir) if args.state_dir else _default_state_dir()
    try:
        json_path, md_path = persist_surprise(record, state_dir)
    except (OSError, FileExistsError) as exc:
        print(f"research-state surprise-store: cannot persist: {exc}", file=sys.stderr)
        return 1
    print(f"stored {record['surprise_id']} -> {json_path}")
    print(f"rendered -> {md_path}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="research-state", description=__doc__
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_collect = sub.add_parser("collect", help="collect a research-state packet")
    p_collect.add_argument("--scope", default=str(_default_scope_path()))
    p_collect.add_argument("--state-dir", default=str(_default_state_dir()))
    p_collect.add_argument("--nixos-repo", default=None)
    p_collect.add_argument("--ca-repo", default=None)
    p_collect.add_argument("--personal-root", default=None)
    p_collect.add_argument("--wiki-root", default=None)
    p_collect.set_defaults(func=cmd_collect)

    p_render = sub.add_parser("render", help="render a packet as Markdown")
    p_render.add_argument("packet", nargs="?", default=None)
    p_render.add_argument("--input", default=None)
    p_render.add_argument("--format", choices=["markdown", "text"], default="markdown")
    p_render.set_defaults(func=cmd_render)

    p_validate = sub.add_parser("validate", help="validate a packet file")
    p_validate.add_argument("packet", nargs="?", default=None)
    p_validate.add_argument("--input", default=None)
    p_validate.set_defaults(func=cmd_validate)

    p_sval = sub.add_parser(
        "salience-validate", help="validate a salience record (shape, not approval)"
    )
    p_sval.add_argument("record", nargs="?", default=None)
    p_sval.add_argument("--input", default=None)
    p_sval.add_argument(
        "--packet", default=None, help="reference packet for ref validation"
    )
    p_sval.set_defaults(func=cmd_salience_validate)

    p_sstore = sub.add_parser(
        "salience-store", help="validate and store a salience record (JSON+Markdown)"
    )
    p_sstore.add_argument("record", nargs="?", default=None)
    p_sstore.add_argument("--input", default=None)
    p_sstore.add_argument("--state-dir", default=str(_default_state_dir()))
    p_sstore.add_argument(
        "--packet", default=None, help="reference packet for ref validation"
    )
    p_sstore.set_defaults(func=cmd_salience_store)

    p_cval = sub.add_parser(
        "contract-validate", help="validate a draft contract (shape, not authorization)"
    )
    p_cval.add_argument("contract", nargs="?", default=None)
    p_cval.add_argument("--input", default=None)
    p_cval.add_argument(
        "--packet", default=None, help="reference packet for ref validation"
    )
    p_cval.set_defaults(func=cmd_contract_validate)

    p_cstore = sub.add_parser(
        "contract-store", help="validate and store a draft contract (JSON+Markdown)"
    )
    p_cstore.add_argument("contract", nargs="?", default=None)
    p_cstore.add_argument("--input", default=None)
    p_cstore.add_argument("--state-dir", default=str(_default_state_dir()))
    p_cstore.add_argument(
        "--packet", default=None, help="reference packet for ref validation"
    )
    p_cstore.set_defaults(func=cmd_contract_store)

    p_aval = sub.add_parser(
        "attempt-validate",
        help="validate an attempt record (shape/lifecycle, not approval)",
    )
    p_aval.add_argument("record", nargs="?", default=None)
    p_aval.add_argument("--input", default=None)
    p_aval.add_argument(
        "--expect-stage",
        choices=list(ATTEMPT_STAGES),
        default=None,
        help="require this lifecycle stage",
    )
    p_aval.add_argument("--packet", default=None)
    p_aval.add_argument("--after-packet", default=None)
    p_aval.add_argument("--fresh-packet", default=None)
    p_aval.add_argument("--contract", default=None)
    p_aval.add_argument("--prior", default=None)
    p_aval.add_argument("--artifact-root", default=None)
    p_aval.set_defaults(func=cmd_attempt_validate)

    def _attempt_store_parser(
        name: str, stage: str, help_text: str, *, fresh: bool = False
    ):
        parser = sub.add_parser(name, help=help_text)
        parser.add_argument("record", nargs="?", default=None)
        parser.add_argument("--input", default=None)
        parser.add_argument("--state-dir", default=str(_default_state_dir()))
        # Storage actions persist immutable records: the baseline/contract
        # references needed for that persistence are mandatory here.
        # Shape-only `attempt-validate` keeps the same flags optional.
        if stage == "start":
            parser.add_argument("--packet", required=True)
            parser.add_argument("--contract", required=True)
        elif stage == "import_result":
            parser.add_argument("--packet", required=True)
            parser.add_argument("--after-packet", required=True)
            parser.add_argument("--contract", required=True)
            parser.add_argument("--prior", required=True)
            parser.add_argument("--artifact-root", required=True)
        elif stage == "decide":
            parser.add_argument("--packet", required=True)
            parser.add_argument("--after-packet", required=True)
            parser.add_argument("--prior", required=True)
        elif stage == "followup":
            parser.add_argument("--packet", required=True)
            parser.add_argument("--after-packet", default=None)
            parser.add_argument("--fresh-packet", required=True)
            parser.add_argument("--prior", required=True)
        else:  # pragma: no cover - unknown stage
            parser.add_argument("--packet", default=None)
            if fresh:
                parser.add_argument("--fresh-packet", default=None)
            parser.add_argument("--contract", default=None)
            parser.add_argument("--prior", default=None)
        parser.set_defaults(func=lambda args, s=stage: cmd_attempt_stage(s, args))
        return parser

    _attempt_store_parser(
        "attempt-start",
        "start",
        "register hypothesis, contract snapshot, and baseline (no results yet)",
    )
    _attempt_store_parser(
        "attempt-import-result",
        "import_result",
        "import post-experiment evidence with provenance (never executes checks)",
    )
    _attempt_store_parser(
        "attempt-decide",
        "decide",
        "record keep/revise/discard/inconclusive with reviewer provenance",
    )
    _attempt_store_parser(
        "attempt-followup",
        "followup",
        "record fresh use against a fresh packet (distinct from first post-test)",
        fresh=True,
    )

    p_tval = sub.add_parser(
        "transfer-validate",
        help="validate a second-object transfer record (shape, not approval)",
    )
    p_tval.add_argument("record", nargs="?", default=None)
    p_tval.add_argument("--input", default=None)
    p_tval.add_argument(
        "--packet", default=None, help="target (second-object) packet for refs"
    )
    p_tval.add_argument(
        "--prior", default=None, help="source attempt record for provenance"
    )
    p_tval.set_defaults(func=cmd_transfer_validate)

    p_tstore = sub.add_parser(
        "transfer-store",
        help="validate and store a transfer record (JSON+Markdown)",
    )
    p_tstore.add_argument("record", nargs="?", default=None)
    p_tstore.add_argument("--input", default=None)
    p_tstore.add_argument("--state-dir", default=str(_default_state_dir()))
    p_tstore.add_argument("--packet", default=None)
    p_tstore.add_argument("--prior", default=None)
    p_tstore.set_defaults(func=cmd_transfer_store)

    p_sval = sub.add_parser(
        "surprise-validate",
        help="validate a useful-surprise handoff (shape, not approval)",
    )
    p_sval.add_argument("record", nargs="?", default=None)
    p_sval.add_argument("--input", default=None)
    p_sval.add_argument(
        "--packet", default=None, help="reference packet for ref validation"
    )
    p_sval.set_defaults(func=cmd_surprise_validate)

    p_sstore = sub.add_parser(
        "surprise-store",
        help="validate and store a surprise handoff (JSON+Markdown)",
    )
    p_sstore.add_argument("record", nargs="?", default=None)
    p_sstore.add_argument("--input", default=None)
    p_sstore.add_argument("--state-dir", default=str(_default_state_dir()))
    p_sstore.add_argument("--packet", default=None)
    p_sstore.set_defaults(func=cmd_surprise_store)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if getattr(args, "command", None) in ("render", "validate") and not (
        args.packet or args.input
    ):
        parser.error("render/validate requires PACKET")
    try:
        return int(args.func(args))
    except BrokenPipeError:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

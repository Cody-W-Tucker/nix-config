#!/usr/bin/env python3
"""Fixture tests for research-state Slice A. Stdlib unittest only.

All Git fixtures live in automatically-created isolated repos under a
.salience-* temp dir inside /etc/nixos; nothing here commits the real repo
or reads private live inputs.
"""

import datetime
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve()
RESEARCH_DIR = HERE.parents[1]
REPO_ROOT = HERE.parents[4]
MAIN_PY = RESEARCH_DIR / "main.py"
SCOPE_JSON = RESEARCH_DIR / "scope.json"

sys.path.insert(0, str(RESEARCH_DIR))

import main as rs  # noqa: E402


FIXED_NOW = datetime.datetime(2026, 10, 1, 12, 0, 0, tzinfo=datetime.timezone.utc)


def make_temp_root(testcase):
    tmp = tempfile.TemporaryDirectory(prefix=".salience-test-", dir=str(REPO_ROOT))
    testcase.addCleanup(tmp.cleanup)
    return Path(tmp.name)


def init_repo(root: Path, name: str) -> tuple[Path, str]:
    repo = root / name
    repo.mkdir()
    subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True, timeout=30)
    (repo / "fixture.txt").write_text("explicit fixture\n", encoding="utf-8")
    subprocess.run(["git", "-C", str(repo), "add", "fixture.txt"], check=True, timeout=30)
    subprocess.run(
        [
            "git", "-C", str(repo),
            "-c", "user.name=Fixture",
            "-c", "user.email=fixture@example.invalid",
            "-c", "core.hooksPath=/dev/null",
            "commit", "-q", "-m", "fixture",
        ],
        check=True,
        timeout=30,
    )
    head = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True, timeout=30,
    ).stdout.strip()
    return repo, head


def write_lock(nix_repo: Path, head: str, node_key: str = "ca") -> Path:
    lock = {
        "version": 7,
        "root": "root",
        "nodes": {
            "root": {"inputs": {"cognitive-assistant": node_key}},
            node_key: {
                "locked": {
                    "type": "github",
                    "owner": "fixture",
                    "repo": "fixture",
                    "rev": head,
                }
            },
        },
    }
    lock_path = nix_repo / "flake.lock"
    lock_path.write_text(json.dumps(lock), encoding="utf-8")
    return lock_path


def make_scope(
    nix_repo: Path,
    ca_repo: Path,
    note: Path,
    *,
    services: list | None = None,
    outcome_readers: list | None = None,
    qmd: dict | None = None,
) -> dict:
    generation = note.parent / "generation"
    generation.mkdir(exist_ok=True)
    system_link = note.parent / "current-system"
    if system_link.is_symlink() or system_link.exists():
        pass
    else:
        system_link.symlink_to(generation)
    return {
        "schema": "research-state-scope/v1",
        "working_object": {
            "id": "fixture-research",
            "description": "Explicit fixture research continuity",
        },
        "repositories": [
            {"id": "nixos", "path": str(nix_repo)},
            {"id": "ca", "path": str(ca_repo)},
        ],
        "pins": {
            "repository": "nixos",
            "file": "flake.lock",
            "inputs": ["cognitive-assistant"],
            "comparisons": [
                {"input": "cognitive-assistant", "repository": "ca"}
            ],
        },
        "deployment": {
            "system": str(system_link),
            "user_candidates": [str(note.parent / "missing-user-generation")],
        },
        "notes": [
            {
                "id": "ideal",
                "path": str(note),
                "line_ranges": [[1, 2]],
                "role": "authored_direction",
                "superseded_by": [],
            }
        ],
        "services": services if services is not None else [],
        "interfaces": [],
        "outcome_readers": (
            outcome_readers
            if outcome_readers is not None
            else [{"id": "ca-decisions", "enabled": False, "reason": "no verified schema"}]
        ),
        "qmd": qmd if qmd is not None else {"enabled": False},
        "limits": {"timeout_seconds": 2, "max_bytes": 16384},
    }


def write_note(root: Path) -> Path:
    note = root / "ideal.md"
    note.write_text(
        "Improve real work through evidence.\n"
        "Keep human authority explicit.\n"
        "PRIVATE_OUTSIDE_SELECTED_RANGE\n",
        encoding="utf-8",
    )
    return note


def collect_fixture(testcase, **overrides):
    root = make_temp_root(testcase)
    nix_repo, _ = init_repo(root, "nixos")
    ca_repo, ca_head = init_repo(root, "ca")
    write_lock(nix_repo, ca_head)
    note = write_note(root)
    scope = make_scope(nix_repo, ca_repo, note, **overrides)
    packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
    return root, nix_repo, ca_repo, ca_head, note, scope, packet


def obs_by_id(packet, oid):
    for ob in packet["observations"]:
        if ob["id"] == oid:
            return ob
    raise AssertionError(f"missing observation {oid}")


class JoinTests(unittest.TestCase):
    def test_agreeing_state_produces_no_false_discrepancy(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        self.assertEqual(rs.validate_packet(packet), [])
        comparisons = [
            c for c in packet["comparisons"] if c["kind"] == "checkout_vs_pin"
        ]
        self.assertTrue(comparisons)
        self.assertEqual(comparisons[0]["status"], "agree")
        self.assertFalse(
            any(
                c["kind"] == "deployment" and c["status"] == "different"
                for c in packet["comparisons"]
            )
        )

    def test_pin_disagreement_is_checkout_vs_pin_not_deployed_drift(self):
        # Rebuild explicitly so the lock can disagree with the checkout.
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, "1" * 40)
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
        comparisons = [
            c for c in packet["comparisons"] if c["kind"] == "checkout_vs_pin"
        ]
        self.assertEqual(comparisons[0]["status"], "different")
        ids = {ob["id"] for ob in packet["observations"]}
        self.assertIn(comparisons[0]["left"], ids)
        self.assertIn(comparisons[0]["right"], ids)
        self.assertIn(ca_head, json.dumps(packet))
        self.assertFalse(
            any(
                c["kind"] == "deployment" and c["status"] == "different"
                for c in packet["comparisons"]
            )
        )

    def test_dirty_tree_is_not_deployed_drift(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        (ca_repo / "fixture.txt").write_text("dirty work\n", encoding="utf-8")
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
        git_ca = obs_by_id(packet, "git-ca")
        self.assertTrue(git_ca["facts"]["dirty"])
        comparisons = [
            c for c in packet["comparisons"] if c["kind"] == "checkout_vs_pin"
        ]
        # Same HEAD vs pin: dirty metadata must not flip the comparison.
        self.assertEqual(comparisons[0]["status"], "agree")
        self.assertFalse(
            any(
                c["kind"] == "deployment" and c["status"] == "different"
                for c in packet["comparisons"]
            )
        )

    def test_note_cites_only_selected_ranges(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        note_ob = obs_by_id(packet, "note-ideal")
        self.assertIn("Improve real work through evidence.", note_ob["facts"]["excerpt"])
        self.assertNotIn("PRIVATE_OUTSIDE_SELECTED_RANGE", json.dumps(packet))

    def test_packet_carries_real_join_and_provenance(self):
        _, _, _, ca_head, _, _, packet = collect_fixture(self)
        for key in (
            "packet_id",
            "collected_at",
            "host",
            "working_object",
            "sources",
            "observations",
            "errors",
            "comparisons",
        ):
            self.assertIn(key, packet)
        import socket as _socket

        self.assertEqual(packet["host"], _socket.gethostname())
        self.assertIn(ca_head, json.dumps(packet))
        kinds = {ob["kind"] for ob in packet["observations"]}
        self.assertTrue(
            {"git", "flake_input", "deployment", "note", "outcome"} <= kinds, kinds
        )
        source_ids = {s["id"] for s in packet["sources"]}
        for ob in packet["observations"]:
            self.assertIn(ob["source_id"], source_ids)
            self.assertIn(
                ob["layer"],
                ("declared", "deployed", "verified_available", "unavailable", "unknown"),
            )
        self.assertTrue(
            any(
                ob["kind"] == "deployment" and ob["layer"] == "unknown"
                for ob in packet["observations"]
            )
        )
        self.assertTrue(
            any(
                ob["kind"] == "outcome" and ob["layer"] == "unknown"
                for ob in packet["observations"]
            )
        )


class FailureTests(unittest.TestCase):
    def test_missing_repo_is_unknown_with_explicit_error(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(nix_repo, root / "missing-repo", note)
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
        self.assertTrue(packet["errors"])
        git_ca = obs_by_id(packet, "git-ca")
        self.assertEqual(git_ca["layer"], "unknown")
        self.assertTrue(
            any(c["status"] == "unknown" for c in packet["comparisons"])
        )

    def test_missing_lock_is_unknown_with_error(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
        pin_ob = obs_by_id(packet, "flake-input-cognitive-assistant")
        self.assertEqual(pin_ob["layer"], "unknown")
        self.assertTrue(packet["errors"])

    def test_unreadable_note_is_unknown_with_error(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, root / "a-directory-note")
        (root / "a-directory-note").mkdir()
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
        note_ob = obs_by_id(packet, "note-ideal")
        self.assertEqual(note_ob["layer"], "unknown")
        self.assertTrue(packet["errors"])

    def test_missing_user_generation_is_unknown_not_absent(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        user_obs = [
            ob
            for ob in packet["observations"]
            if ob["id"].startswith("deployment-user-")
        ]
        self.assertTrue(user_obs)
        self.assertTrue(all(ob["layer"] == "unknown" for ob in user_obs))

    def test_disabled_outcome_is_unknown_not_empty_success(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        outcome = obs_by_id(packet, "outcome-ca-decisions")
        self.assertEqual(outcome["layer"], "unknown")
        self.assertFalse(outcome["facts"].get("enabled", True))

    def test_failed_git_status_is_unknown_not_clean_and_no_raw_stderr(self):
        raw_stderr = "RAW_STATUS_SENTINEL_f3a9c1_should_never_persist\nsecond line dump"
        fake_head = "9" * 40

        def runner(cmd, timeout):
            if "rev-parse" in cmd:
                return SimpleNamespace(returncode=0, stdout=fake_head + "\n", stderr="")
            if "status" in cmd:
                return SimpleNamespace(returncode=128, stdout="", stderr=raw_stderr)
            raise AssertionError(f"unexpected command {cmd}")

        _, _, _, _, _, scope, _ = collect_fixture(self)
        packet = rs.collect_packet(
            scope, now_fn=lambda: FIXED_NOW, runner=runner
        )
        git_ca = obs_by_id(packet, "git-ca")
        self.assertEqual(git_ca["layer"], "unknown")
        self.assertNotIn("dirty", git_ca["facts"])
        flat = json.dumps(packet)
        self.assertNotIn("RAW_STATUS_SENTINEL_f3a9c1_should_never_persist", flat)
        self.assertNotIn("second line dump", flat)
        status_errors = [
            e for e in packet["errors"]
            if "status" in str(e.get("operation", "")).lower()
            or "status" in str(e.get("source", "")).lower()
            or "status" in str(e.get("message", "")).lower()
        ]
        self.assertTrue(status_errors, packet["errors"])
        self.assertTrue(any(c["status"] == "unknown" for c in packet["comparisons"]))

    def test_git_timeout_is_safe_unknown(self):
        import subprocess as _sp

        def timeout_runner(cmd, timeout):
            raise _sp.TimeoutExpired(cmd, timeout)

        _, _, _, _, _, scope, _ = collect_fixture(self)
        packet = rs.collect_packet(
            scope, now_fn=lambda: FIXED_NOW, runner=timeout_runner
        )
        self.assertEqual(obs_by_id(packet, "git-ca")["layer"], "unknown")
        self.assertTrue(packet["errors"])
        self.assertTrue(
            any(c["status"] == "unknown" for c in packet["comparisons"])
        )

    def test_service_projection_uses_allowlist_only(self):
        show_output = (
            "Id=hermes-agent.service\n"
            "LoadState=loaded\n"
            "ActiveState=active\n"
            "SubState=running\n"
            "Result=success\n"
            "ExecMainStatus=0\n"
            "ActiveEnterTimestamp=Thu 2026-10-01 12:00:00 UTC\n"
            "Environment=SECRET_TOKEN=abc123\n"
            "ExecStart=/bin/hermes --token abc123\n"
        )

        def runner(cmd, timeout):
            self.assertNotIn("status", cmd)
            self.assertNotIn("cat", cmd)
            return SimpleNamespace(returncode=0, stdout=show_output, stderr="")

        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(
            nix_repo,
            ca_repo,
            note,
            services=[{"id": "hermes-agent", "unit": "hermes-agent.service", "manager": "user"}],
        )
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW, runner=runner)
        svc = obs_by_id(packet, "service-hermes-agent")
        self.assertEqual(svc["layer"], "verified_available")
        self.assertEqual(svc["facts"]["ActiveState"], "active")
        flat = json.dumps(packet)
        self.assertNotIn("Environment=", flat)
        self.assertNotIn("ExecStart", flat)
        self.assertNotIn("SECRET_TOKEN", flat)

    def test_missing_systemctl_is_unknown(self):
        def runner(cmd, timeout):
            raise FileNotFoundError("systemctl")

        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(
            nix_repo,
            ca_repo,
            note,
            services=[{"id": "svc", "unit": "svc.service", "manager": "system"}],
        )
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW, runner=runner)
        self.assertEqual(obs_by_id(packet, "service-svc")["layer"], "unknown")
        self.assertTrue(packet["errors"])

    def test_qmd_unavailable_is_unknown(self):
        def runner(cmd, timeout):
            if cmd[0] == "qmd":
                raise FileNotFoundError("qmd")
            return SimpleNamespace(returncode=1, stdout="", stderr="nope")

        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(
            nix_repo, ca_repo, note, qmd={"enabled": True}
        )
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW, runner=runner)
        self.assertEqual(obs_by_id(packet, "qmd-status")["layer"], "unknown")
        self.assertTrue(packet["errors"])

    def test_qmd_output_keeps_raw_freshness_without_timestamp_inference(self):
        def runner(cmd, timeout):
            return SimpleNamespace(
                returncode=0, stdout="overall Updated 2d ago\n", stderr=""
            )

        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note, qmd={"enabled": True})
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW, runner=runner)
        qmd_ob = obs_by_id(packet, "qmd-status")
        self.assertEqual(qmd_ob["layer"], "verified_available")
        self.assertIn("Updated 2d ago", qmd_ob["facts"]["output"])
        self.assertEqual(qmd_ob["observed_at"], packet["collected_at"])

    def test_large_output_is_bounded(self):
        big = "x" * 100000

        def runner(cmd, timeout):
            return SimpleNamespace(returncode=0, stdout=big, stderr="")

        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note, qmd={"enabled": True})
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW, runner=runner)
        qmd_ob = obs_by_id(packet, "qmd-status")
        self.assertTrue(qmd_ob["facts"]["truncated"])
        self.assertLessEqual(len(qmd_ob["facts"]["output"]), 16384)

    def test_enabled_outcome_projects_allowlisted_fields_only(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        outcome_file = root / "decisions.json"
        outcome_file.write_text(
            json.dumps(
                {
                    "schema": "ca-decisions/v1",
                    "id": "d1",
                    "decision": "keep",
                    "secret_notes": "PRIVATE_SHOULD_NOT_APPEAR",
                    "token": "PRIVATE_TOKEN",
                }
            ),
            encoding="utf-8",
        )
        scope = make_scope(
            nix_repo,
            ca_repo,
            note,
            outcome_readers=[
                {"id": "ca-decisions", "enabled": True, "path": str(outcome_file)}
            ],
        )
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
        outcome = obs_by_id(packet, "outcome-ca-decisions")
        self.assertEqual(outcome["layer"], "verified_available")
        self.assertEqual(outcome["facts"]["projected"]["decision"], "keep")
        flat = json.dumps(packet)
        self.assertNotIn("PRIVATE_SHOULD_NOT_APPEAR", flat)
        self.assertNotIn("PRIVATE_TOKEN", flat)


class ScopeValidationTests(unittest.TestCase):
    def write_scope(self, root: Path, scope: dict) -> Path:
        path = root / "scope.json"
        path.write_text(json.dumps(scope), encoding="utf-8")
        return path

    def base(self, root, nix_repo, ca_repo, note) -> dict:
        return make_scope(nix_repo, ca_repo, note)

    def test_default_scope_is_research_not_proc_statistics(self):
        scope = json.loads(SCOPE_JSON.read_text(encoding="utf-8"))
        text = json.dumps(scope)
        self.assertIn("/etc/nixos", text)
        self.assertIn("/home/codyt/Projects/Cognitive-Assistant", text)
        self.assertIn("Thesis and Architecture.md", text)
        self.assertTrue(scope.get("repositories"))
        self.assertTrue(scope.get("notes"))
        self.assertTrue(scope.get("services"))
        self.assertNotIn("/proc/loadavg", text)
        self.assertNotIn("/proc/meminfo", text)
        loaded = rs.load_scope(SCOPE_JSON)
        self.assertEqual(loaded["schema"], "research-state-scope/v1")

    def test_rejects_wrong_schema(self):
        root = make_temp_root(self)
        path = root / "scope.json"
        path.write_text('{"schema":"wrong/v9"}', encoding="utf-8")
        with self.assertRaises(ValueError):
            rs.load_scope(path)

    def test_rejects_missing_working_object(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, _ = init_repo(root, "ca")
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        del scope["working_object"]
        with self.assertRaises(ValueError):
            rs.load_scope(self.write_scope(root, scope))

    def test_rejects_bad_line_ranges(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, _ = init_repo(root, "ca")
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        scope["notes"][0]["line_ranges"] = [[0, 5]]
        with self.assertRaises(ValueError):
            rs.load_scope(self.write_scope(root, scope))

    def test_rejects_unknown_pin_repository(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, _ = init_repo(root, "ca")
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        scope["pins"]["comparisons"] = [
            {"input": "cognitive-assistant", "repository": "nope"}
        ]
        with self.assertRaises(ValueError):
            rs.load_scope(self.write_scope(root, scope))

    def test_rejects_bad_limits(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, _ = init_repo(root, "ca")
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        scope["limits"]["timeout_seconds"] = 0
        with self.assertRaises(ValueError):
            rs.load_scope(self.write_scope(root, scope))

    def test_rejects_non_json(self):
        root = make_temp_root(self)
        path = root / "scope.json"
        path.write_text("not json {", encoding="utf-8")
        with self.assertRaises(ValueError):
            rs.load_scope(path)


class PacketValidationTests(unittest.TestCase):
    def test_validate_accepts_good_packet(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        self.assertEqual(rs.validate_packet(packet), [])

    def test_validate_rejects_bad_schema(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        packet["schema"] = "wrong/v9"
        self.assertTrue(rs.validate_packet(packet))

    def test_validate_rejects_dangling_source(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        packet["observations"][0]["source_id"] = "missing-source"
        self.assertTrue(rs.validate_packet(packet))

    def test_validate_rejects_bad_layer(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        packet["observations"][0]["layer"] = "healthy"
        self.assertTrue(rs.validate_packet(packet))

    def test_validate_rejects_dangling_comparison_ref(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        packet["comparisons"][0]["left"] = "missing-observation"
        self.assertTrue(rs.validate_packet(packet))

    def test_validate_rejects_non_utc_timestamp(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        packet["collected_at"] = "2026-10-01T12:00:00+02:00"
        self.assertTrue(rs.validate_packet(packet))


class CliTests(unittest.TestCase):
    def run_cli(self, *argv, env_extra=None):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        if env_extra:
            env.update(env_extra)
        return subprocess.run(
            [sys.executable, str(MAIN_PY), *argv],
            capture_output=True,
            text=True,
            timeout=60,
            cwd=str(REPO_ROOT),
            env=env,
        )

    def fixture_scope_file(self, root: Path) -> Path:
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, _ = init_repo(root, "ca")
        head = subprocess.run(
            ["git", "-C", str(ca_repo), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True, timeout=30,
        ).stdout.strip()
        write_lock(nix_repo, head)
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        path = root / "scope.json"
        path.write_text(json.dumps(scope), encoding="utf-8")
        return path

    def latest_packet(self, state: Path) -> tuple[Path, dict]:
        packets = []
        for path in state.rglob("*.json"):
            value = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(value, dict) and value.get("schema") == "research-state/v1":
                packets.append((path, value))
        self.assertTrue(packets, "no packet persisted under --state-dir")
        return max(packets, key=lambda pair: pair[0].stat().st_mtime_ns)

    def test_help_lists_required_overrides(self):
        proc = self.run_cli("collect", "--help")
        self.assertEqual(proc.returncode, 0)
        for flag in (
            "--scope",
            "--state-dir",
            "--nixos-repo",
            "--ca-repo",
            "--personal-root",
            "--wiki-root",
        ):
            self.assertIn(flag, proc.stdout)

    def test_collect_persists_private_immutable_unique_packets(self):
        root = make_temp_root(self)
        scope_file = self.fixture_scope_file(root)
        state = root / "state"
        first = self.run_cli(
            "collect", "--scope", str(scope_file), "--state-dir", str(state)
        )
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        p1, packet1 = self.latest_packet(state)
        before = p1.read_bytes()
        second = self.run_cli(
            "collect", "--scope", str(scope_file), "--state-dir", str(state)
        )
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        p2, packet2 = self.latest_packet(state)
        self.assertNotEqual(p1, p2)
        self.assertNotEqual(packet1["packet_id"], packet2["packet_id"])
        self.assertEqual(p1.read_bytes(), before)
        self.assertEqual(stat.S_IMODE(p1.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(state.stat().st_mode), 0o700)
        self.assertTrue((p1.with_suffix(".md")).exists())

    def test_render_markdown_matches_json_evidence(self):
        root = make_temp_root(self)
        scope_file = self.fixture_scope_file(root)
        state = root / "state"
        proc = self.run_cli(
            "collect", "--scope", str(scope_file), "--state-dir", str(state)
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        path, packet = self.latest_packet(state)
        rendered = self.run_cli("render", str(path))
        self.assertEqual(rendered.returncode, 0, rendered.stdout + rendered.stderr)
        self.assertIn(packet["packet_id"], rendered.stdout)
        git_ca = obs_by_id(packet, "git-ca")
        self.assertIn(git_ca["facts"]["head"], rendered.stdout)
        self.assertIn("unknown", rendered.stdout.lower())
        self.assertIn("Improve real work through evidence.", rendered.stdout)

    def test_validate_roundtrip(self):
        root = make_temp_root(self)
        scope_file = self.fixture_scope_file(root)
        state = root / "state"
        proc = self.run_cli(
            "collect", "--scope", str(scope_file), "--state-dir", str(state)
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        path, _ = self.latest_packet(state)
        valid = self.run_cli("validate", str(path))
        self.assertEqual(valid.returncode, 0, valid.stdout + valid.stderr)
        self.assertIn("OK", valid.stdout)

    def test_missing_repo_then_explicit_override_fixes_it(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, _ = init_repo(root, "ca")
        head = subprocess.run(
            ["git", "-C", str(ca_repo), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True, timeout=30,
        ).stdout.strip()
        write_lock(nix_repo, head)
        note = write_note(root)
        scope = make_scope(nix_repo, root / "missing-repo", note)
        scope_file = root / "scope.json"
        scope_file.write_text(json.dumps(scope), encoding="utf-8")
        state = root / "state"
        proc = self.run_cli(
            "collect", "--scope", str(scope_file), "--state-dir", str(state)
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        _, packet = self.latest_packet(state)
        self.assertTrue(packet["errors"])
        self.assertTrue(any(c["status"] == "unknown" for c in packet["comparisons"]))
        fixed = self.run_cli(
            "collect",
            "--scope",
            str(scope_file),
            "--state-dir",
            str(state),
            "--ca-repo",
            str(ca_repo),
        )
        self.assertEqual(fixed.returncode, 0, fixed.stdout + fixed.stderr)
        _, repaired = self.latest_packet(state)
        self.assertTrue(
            any(
                c["kind"] == "checkout_vs_pin" and c["status"] == "agree"
                for c in repaired["comparisons"]
            )
        )


class OverrideMismatchTests(unittest.TestCase):
    def test_personal_root_with_no_match_raises(self):
        _, _, _, _, _, scope, _ = collect_fixture(self)
        # Fixture note lives under a temp root, not the Personal default.
        with self.assertRaises(ValueError):
            rs.apply_overrides(scope, personal_root="/tmp/personal-override-fixture")

    def test_wiki_root_with_no_match_raises(self):
        _, _, _, _, _, scope, _ = collect_fixture(self)
        with self.assertRaises(ValueError):
            rs.apply_overrides(scope, wiki_root="/tmp/wiki-override-fixture")

    def test_missing_repo_id_override_raises(self):
        _, _, _, _, _, scope, _ = collect_fixture(self)
        scope["repositories"] = [
            {"id": "custom", "path": scope["repositories"][0]["path"]}
        ]
        scope["pins"]["repository"] = "custom"
        scope["pins"]["comparisons"] = []
        # Need at least one comparison for load_scope, so keep valid shape:
        # instead drop to a scope dict that still validates for overrides.
        with self.assertRaises(ValueError):
            rs.apply_overrides(scope, nixos_repo="/tmp/nixos-override")

    def test_personal_root_override_rewrites_personal_notes(self):
        _, _, _, _, _, _, _ = collect_fixture(self)
        scope = {
            "schema": "research-state-scope/v1",
            "working_object": {"id": "w", "description": "d"},
            "repositories": [
                {"id": "nixos", "path": "/tmp/nixos"},
                {"id": "ca", "path": "/tmp/ca"},
            ],
            "pins": {
                "repository": "nixos",
                "file": "flake.lock",
                "inputs": ["cognitive-assistant"],
                "comparisons": [
                    {"input": "cognitive-assistant", "repository": "ca"}
                ],
            },
            "deployment": {"system": "/tmp/sys", "user_candidates": []},
            "notes": [
                {
                    "id": "n1",
                    "path": "/home/codyt/Knowledge/Personal/note.md",
                    "line_ranges": [[1, 1]],
                    "role": "authored_direction",
                    "superseded_by": [],
                }
            ],
            "services": [],
            "interfaces": [],
            "outcome_readers": [],
            "qmd": {"enabled": False},
            "limits": {"timeout_seconds": 2, "max_bytes": 16384},
        }
        routed = rs.apply_overrides(scope, personal_root="/tmp/personal")
        self.assertEqual(routed["notes"][0]["path"], "/tmp/personal/note.md")

    def test_cli_override_with_no_match_exits_2(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        scope_file = root / "scope.json"
        scope_file.write_text(json.dumps(scope), encoding="utf-8")
        state = root / "state"
        proc = subprocess.run(
            [
                sys.executable, str(MAIN_PY), "collect",
                "--scope", str(scope_file),
                "--state-dir", str(state),
                "--personal-root", str(root / "personal-override"),
            ],
            capture_output=True, text=True, timeout=60,
            cwd=str(REPO_ROOT),
            env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"),
        )
        self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
        self.assertIn("matched no configured", proc.stderr)


class GitUntrackedTests(unittest.TestCase):
    def test_untracked_file_is_dirty_metadata_without_contents(self):
        root = make_temp_root(self)
        nix_repo, _ = init_repo(root, "nixos")
        ca_repo, ca_head = init_repo(root, "ca")
        write_lock(nix_repo, ca_head)
        secret = ca_repo / "untracked-secret.txt"
        secret.write_text("UNTRACKED_CONTENTS_SHOULD_NOT_APPEAR\n", encoding="utf-8")
        note = write_note(root)
        scope = make_scope(nix_repo, ca_repo, note)
        packet = rs.collect_packet(scope, now_fn=lambda: FIXED_NOW)
        git_ca = obs_by_id(packet, "git-ca")
        self.assertTrue(git_ca["facts"]["dirty"])
        self.assertIn("untracked-secret.txt", json.dumps(git_ca["facts"]))
        self.assertNotIn("UNTRACKED_CONTENTS_SHOULD_NOT_APPEAR", json.dumps(packet))
        self.assertGreaterEqual(git_ca["facts"].get("untracked_count", 0), 1)


class BoundedRunnerTests(unittest.TestCase):
    def test_default_runner_caps_stdout_stderr(self):
        proc = rs.default_runner(
            [
                sys.executable, "-c",
                "import sys; sys.stdout.write('x'*100000); "
                "sys.stderr.write('e'*100000)",
            ],
            10,
            16384,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(proc.truncated)
        self.assertLessEqual(len(proc.stdout), 16384)
        self.assertLessEqual(len(proc.stderr), 16384)

    def test_default_runner_timeout_raises_and_kills(self):
        import subprocess as _sp

        with self.assertRaises(_sp.TimeoutExpired):
            rs.default_runner(
                [sys.executable, "-c", "import time; time.sleep(10)"],
                1,
                16384,
            )

    def test_default_runner_rejects_shell_strings(self):
        with self.assertRaises(ValueError):
            rs.default_runner("echo hi", 5, 16384)


class ValidatorDuplicateTests(unittest.TestCase):
    def test_rejects_duplicate_source_ids(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        packet["sources"].append(dict(packet["sources"][0]))
        errors = rs.validate_packet(packet)
        self.assertTrue(any("duplicate source id" in e for e in errors), errors)

    def test_rejects_duplicate_observation_ids(self):
        _, _, _, _, _, _, packet = collect_fixture(self)
        packet["observations"].append(dict(packet["observations"][0]))
        errors = rs.validate_packet(packet)
        self.assertTrue(
            any("duplicate observation id" in e for e in errors), errors
        )


class DefaultScopeQmdTests(unittest.TestCase):
    def test_default_scope_enables_bounded_qmd_status(self):
        scope = json.loads(SCOPE_JSON.read_text(encoding="utf-8"))
        self.assertTrue(scope["qmd"]["enabled"])
        for query in scope["qmd"].get("queries", []):
            self.assertEqual(query.get("collection", "Personal"), "Personal")
            self.assertLessEqual(len(query["terms"]), 200)


if __name__ == "__main__":
    unittest.main()

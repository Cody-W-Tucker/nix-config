#!/usr/bin/env python3
"""Fixture tests for research-state Slice D (second-object transfer).

Stdlib unittest only. All Git fixtures live in automatically-created
isolated repos under a .salience-* temp dir inside /etc/nixos; nothing here
commits the real repo or reads private live inputs.

Slice D exercises a DISTINCT second working object through the SAME
scope/packet/contract/attempt interfaces (explicit alternate scope, no
hardcoded first-object names), then records a small transfer: the source
attempt and its constraints, the source-status/applicability check, and an
adapt-or-decline with evidence plus later contact. An optional useful
surprise is a separate operator handoff with no score. There is no
timer/cron/scheduler/daemon here by design. Both objects are
fixtures/mechanics proof, never live operator outcomes.
"""

import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve()
RESEARCH_DIR = HERE.parents[1]
REPO_ROOT = HERE.parents[4]
MAIN_PY = RESEARCH_DIR / "main.py"
EXAMPLE_SECOND_SCOPE = RESEARCH_DIR / "examples" / "second-object-scope.json"

sys.path.insert(0, str(RESEARCH_DIR))

import main as rs  # noqa: E402
import importlib.util as _ilu


def _load_slice_a():
    spec = _ilu.spec_from_file_location(
        "slice_a_fixtures", str(HERE.parent / "test.py")
    )
    assert spec is not None and spec.loader is not None
    module = _ilu.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


slice_a = _load_slice_a()

T1 = "2026-10-04T10:00:00Z"

FIRST_ID = "fixture-first-object"
SECOND_ID = "fixture-second-object"


def make_second_scope(nix_repo, scripts_repo, note, system_link):
    """Alternate fixture scope: distinct object/repo/service-manager/interface."""
    return {
        "schema": "research-state-scope/v1",
        "working_object": {
            "id": SECOND_ID,
            "description": "Fixture second object: package deployment inquiry",
        },
        "repositories": [
            {"id": "nixos", "path": str(nix_repo)},
            {"id": "scripts", "path": str(scripts_repo)},
        ],
        "pins": {
            "repository": "nixos",
            "file": "flake.lock",
            "inputs": ["cognitive-assistant"],
            "comparisons": [
                {"input": "cognitive-assistant", "repository": "scripts"}
            ],
        },
        "deployment": {
            "system": str(system_link),
            "user_candidates": [str(system_link.parent / "missing-user-generation")],
        },
        "notes": [
            {
                "id": "second-direction",
                "path": str(note),
                "line_ranges": [[1, 2]],
                "role": "orientation",
                "superseded_by": [],
            }
        ],
        "services": [
            {
                "id": "second-system-svc",
                "unit": "fixture-second-object.service",
                "manager": "system",
            }
        ],
        "interfaces": [
            {
                "id": "package-cli",
                "inputs": ["packet JSON"],
                "outputs": ["markdown"],
                "constraint": "read-only",
            }
        ],
        "outcome_readers": [
            {
                "id": "second-object-outcomes",
                "enabled": False,
                "reason": "no verified schema for second object yet",
            }
        ],
        "qmd": {"enabled": False},
        "limits": {"timeout_seconds": 5, "max_bytes": 16384},
    }


def fixture_packets(testcase):
    """Two distinct fixture packets: first object + second object."""
    root = slice_a.make_temp_root(testcase)
    nix_repo, _ = slice_a.init_repo(root, "nixos")
    ca_repo, ca_head = slice_a.init_repo(root, "ca")
    scripts_repo, scripts_head = slice_a.init_repo(root, "scripts")
    slice_a.write_lock(nix_repo, ca_head)
    (nix_repo / "second.lock").write_text("placeholder\n", encoding="utf-8")
    # Second lock lives in the same nixos fixture repo file: rewrite it so the
    # scripts comparison agrees (proves mechanics, not live state).
    lock = {
        "version": 7,
        "root": "root",
        "nodes": {
            "root": {"inputs": {"cognitive-assistant": "scripts"}},
            "scripts": {
                "locked": {
                    "type": "github",
                    "owner": "fixture",
                    "repo": "fixture",
                    "rev": scripts_head,
                }
            },
        },
    }
    second_nix = root / "nixos2"
    second_nix.mkdir()
    subprocess.run(
        ["git", "-C", str(second_nix), "init", "-q"], check=True, timeout=30
    )
    (second_nix / "flake.lock").write_text(json.dumps(lock), encoding="utf-8")
    note1 = root / "ideal1.md"
    note1.write_text(
        "Improve real work through evidence.\nKeep human authority explicit.\n",
        encoding="utf-8",
    )
    note2 = root / "ideal2.md"
    note2.write_text(
        "Second object direction.\nOnly what is verified may transfer.\n",
        encoding="utf-8",
    )
    generation = root / "generation"
    generation.mkdir(exist_ok=True)
    system_link = root / "current-system"
    if not (system_link.is_symlink() or system_link.exists()):
        system_link.symlink_to(generation)
    first_scope = slice_a.make_scope(nix_repo, ca_repo, note1)
    first_scope["working_object"] = {
        "id": FIRST_ID,
        "description": "Fixture first object: research continuity",
    }
    second_scope = make_second_scope(second_nix, scripts_repo, note2, system_link)
    first = rs.collect_packet(
        first_scope, scope_label="first-scope.json", now_fn=lambda: slice_a.FIXED_NOW
    )
    second = rs.collect_packet(
        second_scope,
        scope_label="second-scope.json",
        now_fn=lambda: slice_a.FIXED_NOW,
    )
    return root, first, second


def make_prior(attempt_id, decision, working_id):
    """Minimal source-attempt provenance (mirrors decided attempt shape)."""
    return {
        "attempt_id": attempt_id,
        "decision": {"decision": decision},
        "working_object": {"id": working_id},
    }


def make_transfer(
    source_packet,
    target_packet,
    decision,
    status,
    applicability,
    *,
    attempt_id="fixture-attempt-001",
    unverified_interface=False,
    extra=None,
):
    record = {
        "schema": "research-transfer/v1",
        "transfer_id": f"fixture-transfer-{status}",
        "created_at": T1,
        "status": status,
        "source": {
            "attempt_id": attempt_id,
            "packet_id": source_packet["packet_id"],
            "decision": decision,
            "working_object": {
                "id": FIRST_ID,
                "description": "Fixture first object: research continuity",
            },
            "relation": {
                "description": "Joining checkout/pin/deployment/note evidence "
                "in one packet before judging.",
                "constraints": [
                    "read-only collection",
                    "selected note ranges only",
                ],
            },
        },
        "target": {
            "working_object": {
                "id": SECOND_ID,
                "description": "Fixture second object: package deployment inquiry",
            },
            "packet_id": target_packet["packet_id"],
        },
        "applicability": applicability,
        "unverified_interface": unverified_interface,
        "evidence": [
            {
                "observation_id": "git-scripts",
                "description": "Second-object checkout observed in target packet.",
            }
        ],
        "later_contact": {"status": "pending"},
    }
    if status == "adapted":
        record["adaptation"] = {
            "description": "Same join procedure re-scoped to the scripts "
            "checkout with system-manager service evidence."
        }
    if status in ("declined", "insufficient_evidence"):
        record["decline"] = {
            "reason": "Target prerequisite unknown in the target packet; "
            "declining with evidence instead of copying blindly."
        }
    if status == "no_change":
        record["note"] = (
            "No meaningful change surfaced for the second object; "
            "no obligation to fill a cadence."
        )
    if extra:
        record.update(copy.deepcopy(extra))
    return record


def verified_checks():
    return [
        {
            "id": "checkout-present",
            "description": "Second checkout observed.",
            "status": "verified",
        },
        {
            "id": "pin-present",
            "description": "Second pin observed.",
            "status": "verified",
        },
    ]


def unknown_checks():
    return [
        {
            "id": "checkout-present",
            "description": "Second checkout observed.",
            "status": "verified",
        },
        {
            "id": "deployed-correspondence",
            "description": "No deployed correspondence for the second object yet.",
            "status": "unknown",
        },
    ]


def run_cli(testcase, *args):
    root = slice_a.make_temp_root(testcase)
    env = dict(os.environ, TMPDIR=str(root), PYTHONDONTWRITEBYTECODE="1")
    result = subprocess.run(
        [sys.executable, str(MAIN_PY), *args],
        env=env,
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
        timeout=60,
    )
    return result


class SecondObjectTransfer(unittest.TestCase):
    def test_second_scope_collects_distinct_packet(self):
        root, first, second = fixture_packets(self)
        self.assertNotEqual(first["packet_id"], second["packet_id"])
        self.assertEqual(second["working_object"]["id"], SECOND_ID)
        self.assertNotEqual(
            first["working_object"]["id"], second["working_object"]["id"]
        )
        kinds = {ob["kind"] for ob in second["observations"]}
        self.assertTrue(
            {"git", "flake_input", "deployment", "note", "outcome"} <= kinds, kinds
        )
        # Distinct repo/service-manager/interface shape, not first-object reuse.
        source_ids = {s["id"] for s in second["sources"]}
        self.assertIn("repo-scripts", source_ids)
        self.assertIn("service-second-system-svc", source_ids)
        self.assertNotIn("repo-ca", source_ids)
        comparisons = [
            c for c in second["comparisons"] if c["kind"] == "checkout_vs_pin"
        ]
        self.assertTrue(comparisons)
        self.assertEqual(comparisons[0]["status"], "agree")

    def test_valid_adaptation_store_round_trip(self):
        root, first, second = fixture_packets(self)
        record = make_transfer(first, second, "keep", "adapted", verified_checks())
        self.assertEqual(rs.validate_transfer(record), [])
        prior = make_prior("fixture-attempt-001", "keep", FIRST_ID)
        self.assertEqual(
            rs.check_transfer_refs(record, packet=second, prior=prior), []
        )
        record_file = root / "transfer.json"
        record_file.write_text(json.dumps(record), encoding="utf-8")
        packet_file = root / "target.json"
        packet_file.write_text(json.dumps(second), encoding="utf-8")
        prior_file = root / "prior.json"
        prior_file.write_text(json.dumps(prior), encoding="utf-8")
        state = root / "state"
        result = run_cli(
            self,
            "transfer-store",
            str(record_file),
            "--state-dir",
            str(state),
            "--packet",
            str(packet_file),
            "--prior",
            str(prior_file),
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        stored = [
            p
            for p in state.rglob("*.json")
            if json.loads(p.read_text(encoding="utf-8")).get("schema")
            == "research-transfer/v1"
        ]
        self.assertEqual(len(stored), 1)
        self.assertEqual(stored[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(state.stat().st_mode & 0o777, 0o700)
        md = stored[0].with_suffix(".md")
        self.assertTrue(md.exists())
        self.assertIn("fixture-transfer-adapted", md.read_text(encoding="utf-8"))

    def test_decline_when_target_prerequisites_unknown(self):
        root, first, second = fixture_packets(self)
        record = make_transfer(
            first,
            second,
            "keep",
            "adapted",
            unknown_checks(),
            unverified_interface=True,
        )
        errors = rs.validate_transfer(record)
        self.assertTrue(errors, "unknown prerequisites must block 'adapted'")
        declined = make_transfer(
            first,
            second,
            "keep",
            "declined",
            unknown_checks(),
            unverified_interface=True,
        )
        self.assertEqual(rs.validate_transfer(declined), [])
        prior = make_prior("fixture-attempt-001", "keep", FIRST_ID)
        self.assertEqual(
            rs.check_transfer_refs(declined, packet=second, prior=prior), []
        )

    def test_insufficient_evidence_names_unknown(self):
        _, first, second = fixture_packets(self)
        record = make_transfer(
            first, second, "keep", "insufficient_evidence", verified_checks()
        )
        errors = rs.validate_transfer(record)
        self.assertTrue(errors, "insufficient_evidence needs a non-verified check")
        record = make_transfer(
            first, second, "keep", "insufficient_evidence", unknown_checks()
        )
        self.assertEqual(rs.validate_transfer(record), [])

    def test_failed_source_cannot_masquerade_as_precedent(self):
        _, first, second = fixture_packets(self)
        for decision in ("discard", "inconclusive"):
            record = make_transfer(
                first, second, decision, "adapted", verified_checks()
            )
            errors = rs.validate_transfer(record)
            self.assertTrue(
                errors, f"{decision} source must never validate as 'adapted'"
            )
            declined = make_transfer(
                first,
                second,
                decision,
                "declined",
                verified_checks(),
                extra={"reopens": False},
            )
            self.assertEqual(rs.validate_transfer(declined), [])

    def test_dropped_reopen_needs_new_evidence(self):
        _, first, second = fixture_packets(self)
        reopen_bare = make_transfer(
            first, second, "discard", "adapted", verified_checks(),
            extra={"reopens": True},
        )
        self.assertTrue(
            rs.validate_transfer(reopen_bare),
            "reopen without new evidence must fail (mere cadence is not enough)",
        )
        reopened = make_transfer(
            first,
            second,
            "discard",
            "adapted",
            verified_checks(),
            extra={"reopens": True, "new_evidence": ["fresh target packet refs"]},
        )
        self.assertEqual(rs.validate_transfer(reopened), [])
        no_flag = make_transfer(
            first, second, "discard", "declined", verified_checks()
        )
        self.assertTrue(
            rs.validate_transfer(no_flag),
            "a dropped source needs an explicit boolean 'reopens'",
        )

    def test_same_object_transfer_rejected(self):
        _, first, second = fixture_packets(self)
        record = make_transfer(first, second, "keep", "adapted", verified_checks())
        record["target"]["working_object"]["id"] = FIRST_ID
        errors = rs.validate_transfer(record)
        self.assertTrue(errors, "same-object transfer is not a second object")

    def test_evidence_must_cite_target_packet(self):
        _, first, second = fixture_packets(self)
        record = make_transfer(first, second, "keep", "adapted", verified_checks())
        record["evidence"] = [
            {
                "observation_id": "git-ca",
                "description": "First-object evidence reused blindly.",
            }
        ]
        self.assertEqual(rs.validate_transfer(record), [])
        prior = make_prior("fixture-attempt-001", "keep", FIRST_ID)
        errors = rs.check_transfer_refs(record, packet=second, prior=prior)
        self.assertTrue(
            errors, "reused first-object evidence must fail target-packet refs"
        )

    def test_prior_mismatch_rejected(self):
        _, first, second = fixture_packets(self)
        record = make_transfer(first, second, "keep", "adapted", verified_checks())
        wrong = make_prior("other-attempt", "discard", FIRST_ID)
        errors = rs.check_transfer_refs(record, packet=second, prior=wrong)
        self.assertTrue(errors, "mismatched source provenance must fail")

    def test_no_change_is_legitimate(self):
        _, first, second = fixture_packets(self)
        record = make_transfer(
            first, second, "keep", "no_change", verified_checks()
        )
        self.assertEqual(rs.validate_transfer(record), [])
        bare = make_transfer(first, second, "keep", "no_change", verified_checks())
        del bare["note"]
        self.assertTrue(rs.validate_transfer(bare))

    def test_surprise_handoff_no_score(self):
        _, _, second = fixture_packets(self)
        surprise = {
            "schema": "research-surprise/v1",
            "surprise_id": "fixture-surprise-001",
            "created_at": T1,
            "working_object": {"id": SECOND_ID},
            "packet_id": second["packet_id"],
            "connection": {
                "description": "System service state mirrors the package "
                "checkout unexpectedly.",
                "why_now": "Second-object packet surfaced it unasked.",
            },
            "operator": {"status": "unknown"},
            "later_contact": {"status": "pending"},
        }
        self.assertEqual(rs.validate_surprise(surprise), [])
        scored = copy.deepcopy(surprise)
        scored["score"] = 0.9
        self.assertTrue(
            rs.validate_surprise(scored), "surprise must never carry a score"
        )
        transfer_scored = make_transfer(
            second, second, "keep", "adapted", verified_checks()
        )
        transfer_scored["surprise_score"] = 1
        self.assertTrue(rs.validate_transfer(transfer_scored))
        for status in ("recognized", "rejected", "unknown"):
            op = copy.deepcopy(surprise)
            op["operator"] = {"status": status}
            self.assertEqual(rs.validate_surprise(op), [])

    def test_no_scheduling_artifacts(self):
        forbidden_files = ("timer", "cron", "schedul", "daemon")
        hits = [
            p.name
            for p in RESEARCH_DIR.rglob("*")
            if p.is_file()
            and any(token in p.name.lower() for token in forbidden_files)
            and ".git" not in p.parts
        ]
        self.assertEqual(hits, [], f"scheduling artifacts forbidden: {hits}")
        src = (RESEARCH_DIR / "main.py").read_text(encoding="utf-8")
        # Scheduling is deliberately absent (stated in the CLI contract);
        # reject actual scheduling constructs, not mere mentions of absence.
        self.assertIn("Scheduling is deliberately absent", src)
        for construct in (
            "OnCalendar",
            "[Timer]",
            "crontab",
            "sched.scheduler",
            "threading.Timer",
        ):
            self.assertNotIn(construct, src)

    def test_no_proc_substitute_and_help_lists_slice_d(self):
        scope = json.loads((RESEARCH_DIR / "scope.json").read_text(encoding="utf-8"))
        text = json.dumps(scope)
        self.assertNotIn("/proc/loadavg", text)
        self.assertNotIn("/proc/meminfo", text)
        result = run_cli(self, "--help")
        self.assertEqual(result.returncode, 0)
        for cmd in (
            "transfer-validate",
            "transfer-store",
            "surprise-validate",
            "surprise-store",
        ):
            self.assertIn(cmd, result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)

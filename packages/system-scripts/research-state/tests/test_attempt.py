#!/usr/bin/env python3
"""Fixture tests for research-state Slice C (manual attempt lifecycle).

Stdlib unittest only. All Git fixtures live in automatically-created
isolated repos under a .salience-* temp dir inside /etc/nixos; nothing here
commits the real repo or reads private live inputs.

Slice C is a bounded manual lifecycle behind the SAME research-state
command: attempt-start / attempt-import-result / attempt-decide /
attempt-followup. The tool never executes experiment commands: acceptance
`command` strings are recorded data. Hermes/operator runs an authorized
experiment outside this collector, then supplies bounded real evidence with
provenance. A JSON boolean is never human consent.
"""

import copy
import hashlib
import json
import os
import socket
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve()
RESEARCH_DIR = HERE.parents[1]
REPO_ROOT = HERE.parents[4]
MAIN_PY = RESEARCH_DIR / "main.py"

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

T1 = "2026-10-02T10:00:00Z"
T2 = "2026-10-02T11:00:00Z"
T3 = "2026-10-02T12:00:00Z"
T4 = "2026-10-03T09:00:00Z"
HYPOTHESIS = (
    "Joining intended/deployed/available evidence in one packet lets Hermes "
    "spot a checkout-vs-pin mismatch without claiming deployment drift."
)
CONDITIONS = ["cond-exec", "cond-human"]


def make_contract(packet, hypothesis=HYPOTHESIS):
    return {
        "schema": "research-contract/v1",
        "contract_id": "fixture-contract-001",
        "created_at": T1,
        "status": "draft",
        "experiment_type": "capability",
        "candidate_id": "join-readiness-probe",
        "packet_id": packet["packet_id"],
        "intended_capability": "Join intended/deployed/available evidence.",
        "direction_refs": [
            {
                "ref": "thesis-architecture:32-38 snapshot",
                "description": "Narrow measurable local-first capabilities first.",
            }
        ],
        "computer_evidence": [
            {"description": "Checkout agrees with pin in fixture."}
        ],
        "prerequisites": [
            {
                "id": "fresh-packet",
                "description": "Fresh live packet re-link.",
                "status": "missing",
            }
        ],
        "hypothesis": hypothesis,
        "mechanism": "Compare the same acceptance conditions before/after.",
        "baseline_plan": "Freeze packet refs and condition IDs before results.",
        "acceptance": [
            {
                "id": "cond-exec",
                "description": "Fixture command output is captured verbatim.",
                "check": {"kind": "executable", "command": "git rev-parse HEAD"},
            },
            {
                "id": "cond-human",
                "description": "Operator confirms the output means agreement.",
                "check": {
                    "kind": "human_review",
                    "review": "Operator reads the captured output.",
                },
            },
        ],
        "falsifying_evidence": "An unknown comparison would void the join.",
        "protected_behavior": "Collector never executes check commands.",
        "counterexample": "A dirty tree is checkout state, not deployment drift.",
        "authority": {
            "reads": ["fixture packet JSON"],
            "writes": [],
            "targets": ["fixture state dir"],
        },
        "cost_limits": {"time": "10 min", "cost": "none"},
        "reversal": "Delete fixture state dir; nothing live changes.",
        "human_gate": {"required": True, "reason": "Operator owns first use."},
        "capability_claim": "unsupported",
    }


def make_start(packet, contract, **overrides):
    record = {
        "schema": "research-attempt/v1",
        "attempt_id": "fixture-attempt-001",
        "stage": "started",
        "started_at": T1,
        "working_object": dict(packet["working_object"]),
        "hypothesis": HYPOTHESIS,
        "contract": {
            "contract_id": contract["contract_id"],
            "sha256": rs.contract_canonical_hash(contract),
            "acceptance_ids": list(CONDITIONS),
            "hypothesis": HYPOTHESIS,
        },
        "baseline": {
            "packet_id": packet["packet_id"],
            "observed_at": T1,
            "input_refs": [{"ref": "flake.lock:cognitive-assistant"}],
            "output_refs": [],
            "conditions": [
                {"id": "cond-exec", "status": "fail"},
                {"id": "cond-human", "status": "unknown"},
            ],
        },
        "authority": {
            "source": "hermes_proposed",
            "status": "manual_review_pending",
            "reviewer": "hermes",
        },
        "protected_behavior": "Collector never executes check commands.",
        "counterexample": "A dirty tree is checkout state, not deployment drift.",
    }
    record.update(overrides)
    return record


def make_artifact(artifact_root, name="evidence/output.txt", body=None):
    """Write real bytes via an actual command; return the artifact entry."""
    target = Path(artifact_root) / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if body is None:
        proc = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            timeout=15,
        )
        assert proc.returncode == 0
        raw = b"fixture command output\n" + proc.stdout
    else:
        raw = body
    target.write_bytes(raw)
    assert len(raw) <= rs.ATTEMPT_MAX_ARTIFACT_BYTES
    return {
        "path": name,
        "media": "text",
        "sha256": hashlib.sha256(raw).hexdigest(),
        "size": len(raw),
        "captured_text": raw.decode("utf-8"),
        "provenance": {
            "produced_by": "fixture sandbox command",
            "produced_at": T2,
            "host": socket.gethostname(),
        },
    }


def to_result(record, artifact, after_packet_id, **overrides):
    record = copy.deepcopy(record)
    record["stage"] = "result"
    record["result"] = {
        "observed_at": T2,
        "host": socket.gethostname(),
        "packet_id": after_packet_id,
        "revisions": [{"repo": "ca", "rev": "f" * 40}],
        "deployed_refs": ["fixture-generation"],
        "costs": {"time": "5 min observed", "cost": "none observed"},
        "failures": [],
        "checks": [
            {
                "id": "cond-exec",
                "baseline": "fail",
                "after": "pass",
                "check_kind": "executable",
                "evidence": "Fixture command exit 0; output captured verbatim.",
            },
            {
                "id": "cond-human",
                "baseline": "unknown",
                "after": "review_required",
                "check_kind": "human_review",
                "evidence": "Needs operator read of the captured output.",
            },
        ],
        "artifacts": [artifact],
    }
    for key, value in overrides.items():
        record["result"][key] = value
    return record


def to_decided(record, outcome="inconclusive", **overrides):
    record = copy.deepcopy(record)
    record["stage"] = "decided"
    record["decision"] = {
        "outcome": outcome,
        "rationale": f"Fixture {outcome}: human check still open.",
        "evidence_refs": ["Fixture command output captured verbatim."],
        "reviewer": "hermes",
        "authority": {
            "source": "hermes_proposed",
            "status": "manual_review_pending",
        },
        "unresolved_unknowns": ["cond-human needs operator read"],
        "decided_at": T3,
        "manual_review": {
            "required": True,
            "reviewer": "codyt",
            "checked_at": T3,
            "note": "Operator to read the captured output.",
        },
        "protected_check": {"passed": True, "detail": "No check ran anything."},
        "counterexample_preserved": True,
    }
    for key, value in overrides.items():
        record["decision"][key] = value
    return record


def to_followed_up(record, fresh_packet_id, **overrides):
    record = copy.deepcopy(record)
    record["stage"] = "followed_up"
    record["followup"] = {
        "fresh_packet_id": fresh_packet_id,
        "observed_at": T4,
        "note": "Reused the join procedure against a fresh packet.",
    }
    for key, value in overrides.items():
        record["followup"][key] = value
    return record


def fixture_packets(testcase):
    """Two fixture packets: baseline and after/fresh (distinct packet_ids)."""
    root = slice_a.make_temp_root(testcase)
    nix_repo, _ = slice_a.init_repo(root, "nixos")
    ca_repo, ca_head = slice_a.init_repo(root, "ca")
    slice_a.write_lock(nix_repo, ca_head)
    note = slice_a.write_note(root)
    scope = slice_a.make_scope(nix_repo, ca_repo, note)
    import datetime

    t1 = datetime.datetime(2026, 10, 2, 10, 0, tzinfo=datetime.timezone.utc)
    t2 = datetime.datetime(2026, 10, 2, 11, 0, tzinfo=datetime.timezone.utc)
    first = rs.collect_packet(scope, now_fn=lambda: t1)
    second = rs.collect_packet(scope, now_fn=lambda: t2)
    assert first["packet_id"] != second["packet_id"]
    return root, scope, first, second


def write_json(path, obj):
    path.write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n")


class AttemptShapeTests(unittest.TestCase):
    def setUp(self):
        self.root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, self.packet = slice_a.collect_fixture(self)
        self.contract = make_contract(self.packet)

    def test_start_shape_valid(self):
        self.assertEqual(rs.validate_attempt(make_start(self.packet, self.contract)), [])

    def test_bad_attempt_id_rejected(self):
        record = make_start(self.packet, self.contract, attempt_id="bad id!")
        self.assertTrue(rs.validate_attempt(record))

    def test_early_result_rejected(self):
        record = make_start(self.packet, self.contract)
        record["stage"] = "started"
        record["result"] = {"observed_at": T2}
        errors = rs.validate_attempt(record)
        self.assertTrue(any("before" in e for e in errors), errors)

    def test_result_without_baseline_packet_link_rejected(self):
        record = make_start(self.packet, self.contract)
        record["stage"] = "result"
        record.pop("baseline")
        errors = rs.validate_attempt(record)
        self.assertTrue(errors)

    def test_changed_condition_set_rejected(self):
        record = make_start(self.packet, self.contract)
        record["baseline"]["conditions"] = [{"id": "cond-exec", "status": "fail"}]
        errors = rs.validate_attempt(record)
        self.assertTrue(any("changed condition set" in e for e in errors), errors)

    def test_secret_metadata_rejected(self):
        record = make_start(self.packet, self.contract)
        record["authority"]["api_token"] = "must-not-be-here"
        errors = rs.validate_attempt(record)
        self.assertTrue(any("secret" in e.lower() for e in errors), errors)

    def test_env_dump_field_rejected(self):
        record = make_start(self.packet, self.contract)
        record["baseline"]["env_dump"] = "must-not-be-here"
        errors = rs.validate_attempt(record)
        self.assertTrue(any("secret" in e.lower() for e in errors), errors)

    def test_traversal_artifact_rejected(self):
        record = to_result(
            make_start(self.packet, self.contract),
            {
                "path": "../escape.txt",
                "media": "text",
                "sha256": "a" * 64,
                "size": 1,
                "provenance": {
                    "produced_by": "x",
                    "produced_at": T2,
                    "host": "h",
                },
                "bytes_outside_scope": True,
            },
            "after-packet",
        )
        errors = rs.validate_attempt(record)
        self.assertTrue(any("traversal" in e for e in errors), errors)

    def test_absolute_artifact_rejected(self):
        record = to_result(
            make_start(self.packet, self.contract),
            {
                "path": "/etc/passwd",
                "media": "text",
                "sha256": "a" * 64,
                "size": 1,
                "provenance": {
                    "produced_by": "x",
                    "produced_at": T2,
                    "host": "h",
                },
                "bytes_outside_scope": True,
            },
            "after-packet",
        )
        self.assertTrue(rs.validate_attempt(record))

    def test_secret_filename_rejected(self):
        record = to_result(
            make_start(self.packet, self.contract),
            {
                "path": "evidence/session-token.txt",
                "media": "text",
                "sha256": "a" * 64,
                "size": 1,
                "provenance": {
                    "produced_by": "x",
                    "produced_at": T2,
                    "host": "h",
                },
                "bytes_outside_scope": True,
            },
            "after-packet",
        )
        errors = rs.validate_attempt(record)
        self.assertTrue(any("secret" in e.lower() for e in errors), errors)

    def test_fabricated_bytes_rejected(self):
        record = to_result(
            make_start(self.packet, self.contract),
            {
                "path": "evidence/output.txt",
                "media": "text",
                "sha256": "b" * 64,
                "size": 11,
                "captured_text": "hello world",
                "provenance": {
                    "produced_by": "x",
                    "produced_at": T2,
                    "host": "h",
                },
            },
            "after-packet",
        )
        errors = rs.validate_attempt(record)
        self.assertTrue(any("fabricated" in e for e in errors), errors)

    def test_chronological_tamper_rejected(self):
        record = to_decided(
            to_result(
                make_start(self.packet, self.contract),
                {
                    "path": "evidence/output.txt",
                    "media": "text",
                    "sha256": "a" * 64,
                    "size": 3,
                    "captured_text": "abc",
                    "provenance": {
                        "produced_by": "x",
                        "produced_at": T2,
                        "host": "h",
                    },
                },
                "after-packet",
            ),
            decided_at="2026-10-01T00:00:00Z",
        )
        # captured_text 'abc' does not match sha; fix hash to isolate tamper
        raw = b"abc"
        record["result"]["artifacts"][0]["sha256"] = hashlib.sha256(raw).hexdigest()
        errors = rs.validate_attempt(record)
        self.assertTrue(any("predates" in e for e in errors), errors)

    def test_evil_command_string_never_runs(self):
        canary = self.root / "CANARY-must-not-exist"
        record = to_result(
            make_start(self.packet, self.contract),
            {
                "path": "evidence/output.txt",
                "media": "text",
                "sha256": hashlib.sha256(b"ok").hexdigest(),
                "size": 2,
                "captured_text": "ok",
                "provenance": {
                    "produced_by": "x",
                    "produced_at": T2,
                    "host": "h",
                },
            },
            "after-packet",
        )
        record["result"]["checks"][0]["evidence"] = (
            f"touch {canary}  # a check command string is data, never run"
        )
        decided = to_decided(record)
        self.assertFalse(canary.exists())
        self.assertFalse(
            any("CANARY" in json.dumps(e) for e in rs.validate_attempt(decided)
                if "CANARY" in e)
        )


class DecisionRuleTests(unittest.TestCase):
    def setUp(self):
        self.root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, self.packet = slice_a.collect_fixture(self)
        self.contract = make_contract(self.packet)
        raw = b"fixture bytes"
        self.good_artifact = {
            "path": "evidence/output.txt",
            "media": "text",
            "sha256": hashlib.sha256(raw).hexdigest(),
            "size": len(raw),
            "captured_text": raw.decode("utf-8"),
            "provenance": {
                "produced_by": "fixture",
                "produced_at": T2,
                "host": socket.gethostname(),
            },
        }

    def base_result(self, **overrides):
        return to_result(
            make_start(self.packet, self.contract),
            copy.deepcopy(self.good_artifact),
            "after-packet",
            **overrides,
        )

    def test_missing_check_is_unknown_never_keep(self):
        record = to_decided(self.base_result(), outcome="keep")
        errors = rs.validate_attempt(record)
        self.assertTrue(
            any("human-required" in e or "unknown" in e for e in errors), errors
        )

    def test_review_required_without_reviewed_evidence_blocks_keep(self):
        record = self.base_result()
        record["result"]["checks"][1]["after"] = "review_required"
        decided = to_decided(record, outcome="keep")
        self.assertTrue(rs.validate_attempt(decided))

    def test_keep_with_reviewed_human_check_passes_shape(self):
        record = self.base_result()
        record["result"]["checks"][1].update(
            {"after": "pass", "reviewed_by": "codyt", "checked_at": T3}
        )
        decided = to_decided(
            record,
            outcome="keep",
            unresolved_unknowns=[],
            rationale="Both conditions pass with reviewed human evidence.",
        )
        self.assertEqual(rs.validate_attempt(decided), [])

    def test_human_review_without_reviewer_rejected_even_on_pass(self):
        record = self.base_result()
        record["result"]["checks"][1].update({"after": "pass"})
        decided = to_decided(
            record, outcome="keep", unresolved_unknowns=[]
        )
        errors = rs.validate_attempt(decided)
        self.assertTrue(any("distinct from deterministic" in e for e in errors), errors)

    def test_failed_protected_behavior_prevents_keep(self):
        record = self.base_result()
        record["result"]["checks"][1].update(
            {"after": "pass", "reviewed_by": "codyt", "checked_at": T3}
        )
        decided = to_decided(
            record,
            outcome="keep",
            unresolved_unknowns=[],
            protected_check={"passed": False, "detail": "Regression observed."},
        )
        errors = rs.validate_attempt(decided)
        self.assertTrue(any("protected" in e for e in errors), errors)

    def test_dropped_counterexample_prevents_keep(self):
        record = self.base_result()
        record["result"]["checks"][1].update(
            {"after": "pass", "reviewed_by": "codyt", "checked_at": T3}
        )
        decided = to_decided(
            record,
            outcome="keep",
            unresolved_unknowns=[],
            counterexample_preserved=False,
        )
        errors = rs.validate_attempt(decided)
        self.assertTrue(any("counterexample" in e for e in errors), errors)

    def test_failed_check_prevents_keep_but_allows_revise(self):
        record = self.base_result()
        record["result"]["checks"][0]["after"] = "fail"
        keep = to_decided(record, outcome="keep", unresolved_unknowns=[])
        self.assertTrue(rs.validate_attempt(keep))
        revise = to_decided(record, outcome="revise")
        self.assertEqual(rs.validate_attempt(revise), [])

    def test_changed_inputs_invalidate_keep(self):
        record = self.base_result(inputs_changed=True)
        record["result"]["checks"][1].update(
            {"after": "pass", "reviewed_by": "codyt", "checked_at": T3}
        )
        keep = to_decided(record, outcome="keep", unresolved_unknowns=[])
        self.assertTrue(any("inputs changed" in e for e in rs.validate_attempt(keep)))
        revise = to_decided(record, outcome="revise")
        self.assertEqual(rs.validate_attempt(revise), [])

    def test_failed_and_discarded_retained_as_files(self):
        state = self.root / "state"
        for outcome in ("discard", "inconclusive"):
            record = to_decided(self.base_result(), outcome=outcome)
            self.assertEqual(rs.validate_attempt(record), [])
            json_path, md_path = rs.persist_attempt(record, state)
            stored = json.loads(json_path.read_text())
            self.assertEqual(stored["decision"]["outcome"], outcome)
            self.assertTrue(md_path.exists())

    def test_no_overwrite(self):
        state = self.root / "state"
        record = to_decided(self.base_result(), outcome="discard")
        first_json, _ = rs.persist_attempt(record, state)
        before = first_json.read_bytes()
        second_json, _ = rs.persist_attempt(record, state)
        self.assertNotEqual(first_json, second_json)
        self.assertEqual(first_json.read_bytes(), before)
        with self.assertRaises(FileExistsError):
            rs.atomic_write_private(first_json, b"overwrite attempt")

    def test_dropped_not_recycled_silently(self):
        record = to_followed_up(
            to_decided(self.base_result(), outcome="discard"),
            "fresh-packet-id",
        )
        errors = rs.validate_attempt(record)
        self.assertTrue(any("dropped" in e for e in errors), errors)

    def test_dropped_reopened_with_new_evidence(self):
        record = to_followed_up(
            to_decided(self.base_result(), outcome="discard"),
            "fresh-packet-id",
            reopens="fixture-attempt-001",
            new_evidence="Operator supplied a fresh reading of the output.",
        )
        self.assertEqual(rs.validate_attempt(record), [])

    def test_followup_needs_fresh_packet(self):
        record = to_followed_up(
            to_decided(self.base_result(), outcome="inconclusive"),
            self.packet["packet_id"],
        )
        errors = rs.validate_attempt(record)
        self.assertTrue(any("Fresh use" in e or "fresh use" in e for e in errors), errors)


class CrossRefTests(unittest.TestCase):
    def setUp(self):
        self.root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, self.packet = slice_a.collect_fixture(self)
        self.contract = make_contract(self.packet)

    def test_baseline_packet_mismatch_rejected(self):
        _, _, _, _, _, _, other = slice_a.collect_fixture(self)
        record = make_start(self.packet, self.contract)
        errors = rs.check_attempt_refs(record, packet=other)
        self.assertTrue(any("changed" in e and "baseline" in e for e in errors), errors)

    def test_changed_contract_hash_rejected(self):
        record = make_start(self.packet, self.contract)
        tampered = make_contract(self.packet)
        tampered["mechanism"] = "A different mechanism after baseline."
        errors = rs.check_attempt_refs(record, contract=tampered)
        self.assertTrue(any("hash mismatch" in e for e in errors), errors)

    def test_changed_acceptance_set_rejected(self):
        record = make_start(self.packet, self.contract)
        evolved = make_contract(self.packet)
        evolved["acceptance"].append(
            {
                "id": "cond-new",
                "description": "Added after baseline.",
                "check": {"kind": "executable", "command": "true"},
            }
        )
        errors = rs.check_attempt_refs(record, contract=evolved)
        self.assertTrue(
            any("acceptance IDs changed" in e for e in errors), errors
        )

    def test_changed_hypothesis_needs_new_attempt(self):
        record = make_start(self.packet, self.contract)
        prior = make_start(self.packet, self.contract)
        prior["hypothesis"] = "A different hypothesis."
        prior["contract"]["hypothesis"] = "A different hypothesis."
        errors = rs.check_attempt_refs(record, prior=prior)
        self.assertTrue(any("new attempt" in e for e in errors), errors)

    def test_prior_lineage_mismatch_rejected(self):
        record = make_start(self.packet, self.contract)
        prior = make_start(self.packet, self.contract, attempt_id="other-attempt")
        errors = rs.check_attempt_refs(record, prior=prior)
        self.assertTrue(any("lineage" in e for e in errors), errors)

    def test_prior_must_be_shape_valid_attempt(self):
        record = make_start(self.packet, self.contract)
        record["stage"] = "result"
        prior = make_start(self.packet, self.contract)
        del prior["started_at"]
        del prior["working_object"]
        del prior["authority"]
        del prior["protected_behavior"]
        del prior["counterexample"]
        errors = rs.check_attempt_refs(record, prior=prior)
        self.assertTrue(any("valid prior attempt" in e for e in errors), errors)

    def test_prior_freezes_contract_hash_baseline_and_acceptance(self):
        prior = make_start(self.packet, self.contract)
        # New otherwise-valid contract: same hypothesis/IDs, different body.
        mutated = make_contract(self.packet)
        mutated["mechanism"] = "A different mechanism after baseline."
        self.assertEqual(rs.validate_contract(mutated), [])
        self.assertNotEqual(
            rs.contract_canonical_hash(mutated),
            rs.contract_canonical_hash(self.contract),
        )
        record = make_start(self.packet, mutated)
        # Record matches the new contract, so the live-contract gate passes…
        self.assertEqual(rs.check_attempt_refs(record, contract=mutated), [])
        # …but prior lineage must still reject the silent replacement.
        errors = rs.check_attempt_refs(
            record, contract=mutated, prior=prior
        )
        self.assertTrue(any("prior" in e.lower() for e in errors), errors)
        self.assertTrue(
            any("hash" in e.lower() for e in errors), errors
        )

    def test_prior_freezes_full_baseline(self):
        prior = make_start(self.packet, self.contract)
        record = make_start(self.packet, self.contract)
        record["baseline"] = copy.deepcopy(prior["baseline"])
        record["baseline"]["conditions"] = [
            {"id": "cond-exec", "status": "pass"},
            {"id": "cond-human", "status": "unknown"},
        ]
        errors = rs.check_attempt_refs(record, prior=prior)
        self.assertTrue(any("baseline" in e.lower() for e in errors), errors)

    def test_prior_freezes_acceptance_definitions(self):
        prior = make_start(self.packet, self.contract)
        record = make_start(self.packet, self.contract)
        record["contract"] = copy.deepcopy(prior["contract"])
        record["contract"]["acceptance_ids"] = ["cond-exec", "cond-human", "cond-new"]
        errors = rs.check_attempt_refs(record, prior=prior)
        self.assertTrue(
            any("acceptance" in e.lower() for e in errors), errors
        )

    def test_prior_freezes_result_payload(self):
        prior = to_result(
            make_start(self.packet, self.contract),
            make_artifact(self.root, body=b"ok"),
            "after-packet",
        )
        record = to_decided(prior)
        record["result"]["checks"][0]["after"] = "fail"
        errors = rs.check_attempt_refs(record, prior=prior)
        self.assertTrue(any("result changed" in e for e in errors), errors)

    def test_prior_freezes_decision_payload(self):
        prior = to_decided(
            to_result(
                make_start(self.packet, self.contract),
                make_artifact(self.root, body=b"ok"),
                "after-packet",
            )
        )
        record = to_followed_up(prior, "fresh-packet")
        record["decision"]["rationale"] = "A different decision basis."
        errors = rs.check_attempt_refs(record, prior=prior)
        self.assertTrue(any("decision changed" in e for e in errors), errors)

    def test_prior_valid_progression_preserved(self):
        prior = make_start(self.packet, self.contract)
        record = make_start(self.packet, self.contract)
        record["stage"] = "result"
        self.assertEqual(rs.check_attempt_refs(record, prior=prior), [])
        result = to_result(
            prior,
            make_artifact(self.root, name="evidence/result.txt", body=b"ok"),
            "after-packet",
        )
        self.assertEqual(rs.check_attempt_refs(to_decided(result), prior=result), [])
        decided = to_decided(result)
        self.assertEqual(
            rs.check_attempt_refs(to_followed_up(decided, "fresh-packet"), prior=decided),
            [],
        )

    def test_dangling_evidence_ref_rejected(self):
        record = to_decided(
            to_result(
                make_start(self.packet, self.contract),
                {
                    "path": "evidence/output.txt",
                    "media": "text",
                    "sha256": hashlib.sha256(b"ok").hexdigest(),
                    "size": 2,
                    "captured_text": "ok",
                    "provenance": {
                        "produced_by": "x",
                        "produced_at": T2,
                        "host": "h",
                    },
                },
                self.packet["packet_id"],
            ),
            evidence_refs=[{"description": "Bogus.", "observation_id": "no-such-obs"}],
        )
        errors = rs.check_attempt_refs(record, packet=self.packet)
        self.assertTrue(any("dangling" in e for e in errors), errors)

    def test_symlink_escape_rejected(self):
        artifact_root = self.root / "artifacts"
        (artifact_root / "evidence").mkdir(parents=True)
        outside = self.root / "outside.txt"
        outside.write_bytes(b"outside bytes")
        (artifact_root / "evidence" / "link.txt").symlink_to(outside)
        raw = b"outside bytes"
        record = to_result(
            make_start(self.packet, self.contract),
            {
                "path": "evidence/link.txt",
                "media": "text",
                "sha256": hashlib.sha256(raw).hexdigest(),
                "size": len(raw),
                "captured_text": raw.decode("utf-8"),
                "provenance": {
                    "produced_by": "x",
                    "produced_at": T2,
                    "host": "h",
                },
            },
            "after-packet",
        )
        errors = rs.check_attempt_refs(record, artifact_root=artifact_root)
        self.assertTrue(
            any("outside bytes" in e or "escapes" in e for e in errors), errors
        )


class MechanicsIntegrationTests(unittest.TestCase):
    """Mechanics/integration only: real sandbox command output proves record
    mechanics on in-repo fixture evidence. NOT the first useful NAS loop."""

    def test_complete_fixture_attempt_with_real_command_output(self):
        root, scope, baseline_packet, after_packet = fixture_packets(self)
        contract = make_contract(baseline_packet)
        work = root / "work"
        artifact_root = work / "artifacts"
        artifact_root.mkdir(parents=True)
        state = work / "state"
        packet_file = work / "baseline.json"
        after_file = work / "after.json"
        contract_file = work / "contract.json"
        write_json(packet_file, baseline_packet)
        write_json(after_file, after_packet)
        write_json(contract_file, contract)

        start = make_start(baseline_packet, contract)
        start_file = work / "start.json"
        write_json(start_file, start)

        env = dict(os.environ, TMPDIR=str(root), PYTHONDONTWRITEBYTECODE="1")

        def run(*argv):
            proc = subprocess.run(
                [sys.executable, str(MAIN_PY), *argv],
                cwd=str(REPO_ROOT),
                env=env,
                capture_output=True,
                text=True,
                timeout=60,
            )
            return proc

        proc = run(
            "attempt-start", str(start_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--contract", str(contract_file),
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        stored_starts = sorted(state.glob("attempt-*.json"))
        self.assertEqual(len(stored_starts), 1)

        # Real sandbox experiment: actual command output becomes the artifact.
        artifact = make_artifact(artifact_root)
        result = to_result(start, artifact, after_packet["packet_id"])
        result_file = work / "result.json"
        write_json(result_file, result)
        proc = run(
            "attempt-import-result", str(result_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--after-packet", str(after_file),
            "--contract", str(contract_file),
            "--prior", str(stored_starts[0]),
            "--artifact-root", str(artifact_root),
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

        recorded = json.loads(result_file.read_text())["result"]["artifacts"][0]
        on_disk = (artifact_root / recorded["path"]).read_bytes()
        self.assertEqual(recorded["captured_text"].encode("utf-8"), on_disk)
        self.assertEqual(recorded["sha256"], hashlib.sha256(on_disk).hexdigest())

        # Fabricated bytes fail the same gate the real bytes passed.
        forged = copy.deepcopy(result)
        forged["result"]["artifacts"][0]["captured_text"] += " forged"
        forged_file = work / "forged.json"
        write_json(forged_file, forged)
        proc = run(
            "attempt-import-result", str(forged_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--after-packet", str(after_file),
            "--contract", str(contract_file),
            "--prior", str(stored_starts[0]),
            "--artifact-root", str(artifact_root),
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("fabricated", proc.stdout + proc.stderr)

        stored_results = sorted(
            p for p in state.glob("attempt-*.json") if p not in stored_starts
        )
        self.assertTrue(stored_results)
        prior_result = max(stored_results, key=lambda p: p.stat().st_mtime_ns)

        decided = to_decided(result, outcome="inconclusive")
        decided_file = work / "decided.json"
        write_json(decided_file, decided)
        proc = run(
            "attempt-decide", str(decided_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--after-packet", str(after_file),
            "--prior", str(prior_result),
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

        fresh = rs.collect_packet(
            scope,
            now_fn=lambda: __import__("datetime").datetime(
                2026, 10, 3, 9, 0, tzinfo=__import__("datetime").timezone.utc
            ),
        )
        fresh_file = work / "fresh.json"
        write_json(fresh_file, fresh)
        self.assertNotEqual(fresh["packet_id"], baseline_packet["packet_id"])
        stored_decided = sorted(
            p
            for p in state.glob("attempt-*.json")
            if p not in stored_starts and p != prior_result
        )
        prior_decided = max(stored_decided, key=lambda p: p.stat().st_mtime_ns)
        followed = to_followed_up(decided, fresh["packet_id"])
        followed_file = work / "followed.json"
        write_json(followed_file, followed)
        proc = run(
            "attempt-followup", str(followed_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--fresh-packet", str(fresh_file),
            "--prior", str(prior_decided),
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

        # Private immutable outputs; failures retained as files.
        for path in state.glob("attempt-*.json"):
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(state.stat().st_mode & 0o777, 0o700)
        outcomes = [
            json.loads(p.read_text()).get("stage") for p in state.glob("attempt-*.json")
        ]
        self.assertEqual(
            sorted(outcomes), ["decided", "followed_up", "result", "started"]
        )


class ArtifactAdmissionTests(unittest.TestCase):
    """Content/type admission: obvious dumps rejected, safe bytes allowed.

    Narrow deterministic gates only (private-key blocks, dotenv-style
    secret assignments, credentialed DB URLs, /proc/ps/argv process dumps,
    stack-trace dumps, secret-shaped JSON keys). Ordinary bounded safe
    text and real mechanics output stay allowed. Anything outside the
    allowed capture scope preserves references+hashes via
    `bytes_outside_scope` instead of ingesting bytes. No general redaction
    of arbitrary free text is claimed: never put private bytes here.
    """

    def setUp(self):
        self.root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, self.packet = slice_a.collect_fixture(self)
        self.contract = make_contract(self.packet)

    def _artifact(self, body: bytes, name="evidence/output.txt", media="text"):
        return {
            "path": name,
            "media": media,
            "sha256": hashlib.sha256(body).hexdigest(),
            "size": len(body),
            "captured_text": body.decode("utf-8"),
            "provenance": {
                "produced_by": "fixture admission probe",
                "produced_at": T2,
                "host": "h",
            },
        }

    def _result_with(self, body: bytes, **kw):
        return to_result(
            make_start(self.packet, self.contract),
            self._artifact(body, **kw),
            "after-packet",
        )

    def test_env_dump_rejected(self):
        body = (
            b"DATABASE_URL=postgres://app:s3cret@db:5432/app\n"
            b"API_KEY=abc123\n"
            b"SECRET=topsecret\n"
        )
        errors = rs.validate_attempt(self._result_with(body))
        self.assertTrue(
            any("env" in e.lower() for e in errors), errors
        )

    def test_private_key_rejected(self):
        body = (
            b"-----BEGIN OPENSSH PRIVATE KEY-----\n"
            b"b3BlbnNzaC1rZXktdjEAAAAA\n"
            b"-----END OPENSSH PRIVATE KEY-----\n"
        )
        errors = rs.validate_attempt(self._result_with(body))
        self.assertTrue(
            any("private key" in e.lower() for e in errors), errors
        )

    def test_process_args_dump_rejected(self):
        body = (
            b"USER       PID %CPU COMMAND\n"
            b"root         1  0.0 /sbin/init splash\n"
            b"root       412  0.1 /usr/bin/python3 app.py --token abc\n"
            b"argv[0]=/usr/bin/python3\n"
            b"/proc/412/cmdline\n"
        )
        errors = rs.validate_attempt(self._result_with(body))
        self.assertTrue(
            any("process" in e.lower() for e in errors), errors
        )

    def test_trace_dump_rejected(self):
        body = (
            b"Traceback (most recent call last):\n"
            b'  File "app.py", line 10, in <module>\n'
            b"ValueError: bad value\n"
        )
        errors = rs.validate_attempt(self._result_with(body))
        self.assertTrue(
            any("trace" in e.lower() for e in errors), errors
        )

    def test_json_secret_keys_rejected(self):
        body = b'{"api_key": "abc123", "result": "ok"}\n'
        errors = rs.validate_attempt(
            self._result_with(body, name="evidence/result.json", media="json")
        )
        self.assertTrue(
            any("secret" in e.lower() for e in errors), errors
        )

    def test_safe_text_allowed(self):
        body = b"Fixture join check passed; HEAD clean; no drift claimed.\n"
        self.assertEqual(rs.validate_attempt(self._result_with(body)), [])

    def test_mechanics_output_allowed(self):
        artifact_root = self.root / "artifacts"
        artifact = make_artifact(artifact_root)
        record = to_result(
            make_start(self.packet, self.contract),
            artifact,
            "after-packet",
        )
        self.assertEqual(rs.validate_attempt(record), [])
        self.assertEqual(
            rs.check_attempt_refs(record, artifact_root=artifact_root), []
        )

    def test_outside_scope_preserves_refs(self):
        record = to_result(
            make_start(self.packet, self.contract),
            {
                "path": "evidence/notes.md",
                "media": "markdown",
                "sha256": "f" * 64,
                "size": 100,
                "provenance": {
                    "produced_by": "x",
                    "produced_at": T2,
                    "host": "h",
                },
                "bytes_outside_scope": True,
            },
            "after-packet",
        )
        self.assertEqual(rs.validate_attempt(record), [])

    def test_artifact_file_dump_rejected(self):
        artifact_root = self.root / "artifacts"
        (artifact_root / "evidence").mkdir(parents=True)
        raw = b"SECRET=topsecret\nAPI_KEY=abc123\n"
        (artifact_root / "evidence" / "output.txt").write_bytes(raw)
        record = to_result(
            make_start(self.packet, self.contract),
            self._artifact(raw),
            "after-packet",
        )
        errors = rs.check_attempt_refs(record, artifact_root=artifact_root)
        self.assertTrue(
            any("env" in e.lower() for e in errors), errors
        )

    def test_artifact_file_safe_allowed(self):
        artifact_root = self.root / "artifacts"
        (artifact_root / "evidence").mkdir(parents=True)
        raw = b"Fixture join check passed; HEAD clean.\n"
        (artifact_root / "evidence" / "output.txt").write_bytes(raw)
        record = to_result(
            make_start(self.packet, self.contract),
            self._artifact(raw),
            "after-packet",
        )
        self.assertEqual(
            rs.check_attempt_refs(record, artifact_root=artifact_root), []
        )


class StorageGatingTests(unittest.TestCase):
    """Persistence needs actual registered refs, not self-asserted shape.

    `attempt-start` refuses persistence when the baseline packet/contract
    references are omitted; `attempt-import-result` additionally requires a
    previously persisted started record. Shape-only `attempt-validate` may
    omit them; storage actions must not.
    """

    def _cli(self, env):
        def run(*argv):
            return subprocess.run(
                [sys.executable, str(MAIN_PY), *argv],
                cwd=str(REPO_ROOT),
                env=env,
                capture_output=True,
                text=True,
                timeout=60,
            )
        return run

    def test_start_refuses_omitted_baseline_and_contract(self):
        root, _, baseline, _ = fixture_packets(self)
        contract = make_contract(baseline)
        start = make_start(baseline, contract)
        work = root / "work"
        work.mkdir()
        start_file = work / "start.json"
        write_json(start_file, start)
        state = work / "state"
        env = dict(os.environ, TMPDIR=str(root), PYTHONDONTWRITEBYTECODE="1")
        run = self._cli(env)
        # Omitted --packet/--contract: argparse refuses persistence (exit 2).
        proc = run("attempt-start", str(start_file), "--state-dir", str(state))
        self.assertNotEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertFalse(list(state.glob("attempt-*.json")) if state.exists() else [])
        # Direct stage call without refs is also rejected (no persistence).
        import argparse

        args = argparse.Namespace(
            record=str(start_file),
            input=None,
            state_dir=str(state),
            packet=None,
            contract=None,
        )
        self.assertNotEqual(rs.cmd_attempt_stage("start", args), 0)
        self.assertFalse(list(state.glob("attempt-*.json")) if state.exists() else [])

    def test_import_result_requires_refs_and_persisted_start(self):
        root, _, baseline, after = fixture_packets(self)
        contract = make_contract(baseline)
        work = root / "work"
        work.mkdir()
        artifact_root = work / "artifacts"
        artifact_root.mkdir(parents=True)
        state = work / "state"
        packet_file = work / "baseline.json"
        after_file = work / "after.json"
        contract_file = work / "contract.json"
        write_json(packet_file, baseline)
        write_json(after_file, after)
        write_json(contract_file, contract)
        start = make_start(baseline, contract)
        start_file = work / "start.json"
        write_json(start_file, start)
        env = dict(os.environ, TMPDIR=str(root), PYTHONDONTWRITEBYTECODE="1")
        run = self._cli(env)
        # No prior persisted yet: omitted --prior/--contract must refuse.
        artifact = make_artifact(artifact_root)
        result = to_result(start, artifact, after["packet_id"])
        result_file = work / "result.json"
        write_json(result_file, result)
        proc = run(
            "attempt-import-result", str(result_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--artifact-root", str(artifact_root),
        )
        self.assertNotEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        # Valid start with actual refs persists one started record.
        proc = run(
            "attempt-start", str(start_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--contract", str(contract_file),
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        stored = sorted(state.glob("attempt-*.json"))
        self.assertEqual(len(stored), 1)
        # Detached prior (not under --state-dir) is rejected.
        detached = work / "detached-prior.json"
        detached.write_text(stored[0].read_text())
        proc = run(
            "attempt-import-result", str(result_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--after-packet", str(after_file),
            "--contract", str(contract_file),
            "--prior", str(detached),
            "--artifact-root", str(artifact_root),
        )
        self.assertNotEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        # Valid import with actual refs + persisted start succeeds.
        proc = run(
            "attempt-import-result", str(result_file),
            "--state-dir", str(state),
            "--packet", str(packet_file),
            "--after-packet", str(after_file),
            "--contract", str(contract_file),
            "--prior", str(stored[0]),
            "--artifact-root", str(artifact_root),
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertEqual(len(sorted(state.glob("attempt-*.json"))), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)

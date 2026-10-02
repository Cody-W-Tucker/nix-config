#!/usr/bin/env python3
"""Fixture tests for research-state Slice B (salience + draft contracts).

Stdlib unittest only. All Git fixtures live in automatically-created
isolated repos under a .salience-* temp dir inside /etc/nixos; nothing here
commits the real repo or reads private live inputs.

Slice B is the judgment layer: supplied salience records and draft contracts
get shape/reference validation plus JSON+Markdown storage from the same
record. There is no candidate generator, no LLM API, and no command runner.
Shape validation never authorizes execution.
"""

import copy
import importlib.util
import json
import os
import stat
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve()
RESEARCH_DIR = HERE.parents[1]
REPO_ROOT = HERE.parents[4]
MAIN_PY = RESEARCH_DIR / "main.py"
EXAMPLE_CONTRACT = RESEARCH_DIR / "examples" / "discovery-join-draft.json"
SKILL_MD = (
    REPO_ROOT
    / "modules/services/hermes-agent/skills/knowledge/research/research-state/SKILL.md"
)
SKILLS_DEFAULT_NIX = (
    REPO_ROOT / "modules/services/hermes-agent/skills/knowledge/default.nix"
)

sys.path.insert(0, str(RESEARCH_DIR))

import main as rs  # noqa: E402


def _load_slice_a_helpers():
    spec = importlib.util.spec_from_file_location(
        "slice_a_fixtures", str(HERE.parent / "test.py")
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


slice_a = _load_slice_a_helpers()

CREATED_AT = "2026-10-01T23:30:00Z"


def make_salience(packet, **overrides):
    """A minimal shape-valid candidate salience record linked to packet."""
    src = packet["sources"][0]["id"]
    obs = packet["observations"][0]["id"]
    record = {
        "schema": "research-salience/v1",
        "salience_id": "fixture-salience-001",
        "created_at": CREATED_AT,
        "status": "candidate",
        "working_object": dict(packet["working_object"]),
        "packet_id": packet["packet_id"],
        "direction": [
            {
                "ref": "thesis-architecture:32-38 snapshot",
                "description": "Narrow measurable local-first capabilities first.",
                "source_id": src,
                "observation_id": obs,
            }
        ],
        "decisions": [],
        "boundaries": ["No live execution from this record."],
        "open_questions": ["Can intended/deployed/available rows join?"],
        "observations": ["Checkout agrees with the pin in this fixture packet."],
        "interpretations": ["Agreement is checkout-vs-pin only, not deployment proof."],
        "inputs": [
            {
                "ref": "thesis-architecture:32-38",
                "retrieved_at": "20261001T230813Z",
                "superseded": False,
            },
            {
                "ref": "what-enables (superseded by Problem Landscape et al.)",
                "retrieved_at": "20261001T230813Z",
                "superseded": True,
            },
        ],
        "candidates": [
            {
                "id": "join-readiness-probe",
                "interfaces": {
                    "inputs": ["research-state packet JSON"],
                    "outputs": ["rendered Markdown join"],
                },
                "access_constraints": "read-only; retained packets only",
                "evidence": [
                    {
                        "description": "Checkout agrees with pin in fixture.",
                        "observation_id": obs,
                        "source_id": src,
                    }
                ],
                "prerequisites": [
                    {
                        "id": "fresh-packet",
                        "description": "Fresh live packet re-link.",
                        "status": "missing",
                    }
                ],
                "why_now": "Join readiness is the current working object.",
                "alternatives": ["Report insufficient evidence."],
                "disconfirming_evidence": "An unknown comparison would void the join.",
            }
        ],
    }
    record.update(overrides)
    return record


def make_contract(packet, **overrides):
    """A minimal shape-valid read-only discovery draft linked to packet."""
    obs = packet["observations"][0]["id"]
    src = packet["sources"][0]["id"]
    contract = {
        "schema": "research-contract/v1",
        "contract_id": "fixture-contract-001",
        "created_at": CREATED_AT,
        "status": "draft",
        "experiment_type": "discovery",
        "candidate_id": "join-readiness-probe",
        "packet_id": packet["packet_id"],
        "salience_id": "fixture-salience-001",
        "intended_capability": "Join intended/deployed/available rows read-only.",
        "direction_refs": [
            {
                "ref": "thesis-architecture:38 snapshot",
                "description": "Automate only where verifiable.",
                "source_id": src,
            }
        ],
        "computer_evidence": [
            {
                "description": "Fixture checkout/pin agreement.",
                "observation_id": obs,
                "source_id": src,
            }
        ],
        "prerequisites": [
            {
                "id": "fresh-packet",
                "description": "Fresh live packet re-link.",
                "status": "unknown",
            }
        ],
        "uncertainty": "Unknown whether the rows share joinable keys at all.",
        "hypothesis": "The rows can be joined read-only without claiming drift.",
        "mechanism": "Render and align retained packet rows; change nothing.",
        "baseline_plan": "Record packet id and comparison status first.",
        "acceptance": [
            {
                "id": "refs-relink-clean",
                "description": "Refs re-link against a fresh packet.",
                "check": {
                    "kind": "executable",
                    "command": "research-state contract-validate C --packet P",
                },
            },
            {
                "id": "join-reads-true",
                "description": "Operator judges the join meaningful.",
                "check": {
                    "kind": "human_review",
                    "review": "Operator confirms or rejects the reading.",
                },
            },
        ],
        "falsifying_evidence": "An unknown comparison falsifies joinability.",
        "protected_behavior": "No automatic mutation; human gate on all changes.",
        "counterexample": "A clean join the operator finds un-actionable kills the worthwhile reading.",
        "authority": {
            "reads": ["retained packet JSON"],
            "writes": [],
            "targets": ["${XDG_STATE_HOME:-$HOME/.local/state}/research-state"],
        },
        "cost_limits": {"time": "30 minutes", "cost": "no spend"},
        "reversal": "Nothing to reverse; discard the rendering if unhelpful.",
        "human_gate": {"required": True, "reason": "Needs fresh packet + review."},
        "capability_claim": "unsupported",
    }
    contract.update(overrides)
    return contract


def run_cli(*argv, env_extra=None):
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


class SalienceShapeTests(unittest.TestCase):
    def test_valid_candidate_record_accepted(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        self.assertEqual(rs.validate_salience(make_salience(packet)), [])

    def test_no_candidate_accepted_with_named_gaps(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(
            packet, status="no_candidate", candidates=[], gaps=["No live packet yet."],
            interpretations=[],
        )
        self.assertEqual(rs.validate_salience(record), [])

    def test_insufficient_evidence_accepted_with_gaps(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(
            packet, status="insufficient_evidence", candidates=[],
            gaps=["Private evidence would be needed; refusing to read it."],
            interpretations=[],
        )
        self.assertEqual(rs.validate_salience(record), [])

    def test_no_candidate_must_not_carry_candidates(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(
            packet, status="no_candidate", gaps=["Empty on purpose."],
        )
        errors = rs.validate_salience(record)
        self.assertTrue(any("no candidates" in e for e in errors), errors)

    def test_no_candidate_must_name_gaps(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet, status="no_candidate", candidates=[])
        errors = rs.validate_salience(record)
        self.assertTrue(any("gaps" in e for e in errors), errors)

    def test_candidate_status_needs_candidates(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet, candidates=[])
        errors = rs.validate_salience(record)
        self.assertTrue(any("at least one candidate" in e for e in errors), errors)

    def test_candidate_set_stays_small(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        record["candidates"] = record["candidates"] * 4
        errors = rs.validate_salience(record)
        self.assertTrue(any("at most 3" in e for e in errors), errors)

    def test_candidate_needs_disconfirming_evidence(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        del record["candidates"][0]["disconfirming_evidence"]
        errors = rs.validate_salience(record)
        self.assertTrue(any("disconfirming_evidence" in e for e in errors), errors)

    def test_candidate_needs_evidence_and_interfaces(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        record["candidates"][0]["evidence"] = []
        record["candidates"][0]["interfaces"] = {"inputs": []}
        errors = rs.validate_salience(record)
        self.assertTrue(errors, "empty evidence / partial interfaces must fail")

    def test_input_snapshots_need_provenance(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        record["inputs"] = [{"ref": "thesis-architecture:32-38"}]
        errors = rs.validate_salience(record)
        self.assertTrue(any("retrieved_at" in e for e in errors), errors)
        self.assertTrue(any("superseded" in e for e in errors), errors)

    def test_superseded_snapshot_retained_as_history(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        # superseded=True is valid: history retained, not current instruction.
        self.assertEqual(rs.validate_salience(record), [])
        self.assertTrue(record["inputs"][1]["superseded"])


class SalienceRefTests(unittest.TestCase):
    def test_known_refs_accepted_against_packet(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        self.assertEqual(rs.validate_salience(record), [])
        self.assertEqual(rs.check_salience_refs(record, packet), [])

    def test_dangling_source_ref_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        record["direction"][0]["source_id"] = "no-such-source"
        errors = rs.check_salience_refs(record, packet)
        self.assertTrue(any("dangling source ref" in e for e in errors), errors)

    def test_dangling_observation_ref_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        record["candidates"][0]["evidence"][0]["observation_id"] = "no-such-observation"
        errors = rs.check_salience_refs(record, packet)
        self.assertTrue(any("dangling observation ref" in e for e in errors), errors)

    def test_packet_id_mismatch_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet, packet_id="stale-packet-id")
        errors = rs.check_salience_refs(record, packet)
        self.assertTrue(any("does not match" in e for e in errors), errors)


class ContractShapeTests(unittest.TestCase):
    def test_example_fixture_is_shape_valid(self):
        contract = json.loads(EXAMPLE_CONTRACT.read_text(encoding="utf-8"))
        self.assertEqual(rs.validate_contract(contract), [])

    def test_valid_discovery_draft_accepted(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        self.assertEqual(rs.validate_contract(make_contract(packet)), [])

    def test_missing_protected_behavior_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        del contract["protected_behavior"]
        errors = rs.validate_contract(contract)
        self.assertTrue(any("protected_behavior" in e for e in errors), errors)

    def test_missing_counterexample_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        del contract["counterexample"]
        errors = rs.validate_contract(contract)
        self.assertTrue(any("counterexample" in e for e in errors), errors)

    def test_incomplete_authority_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        contract["authority"]["targets"] = []
        errors = rs.validate_contract(contract)
        self.assertTrue(any("bounded targets" in e for e in errors), errors)

    def test_executable_check_needs_command(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        del contract["acceptance"][0]["check"]["command"]
        errors = rs.validate_contract(contract)
        self.assertTrue(any("need 'command'" in e for e in errors), errors)

    def test_human_review_check_needs_review(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        del contract["acceptance"][1]["check"]["review"]
        errors = rs.validate_contract(contract)
        self.assertTrue(any("need 'review'" in e for e in errors), errors)

    def test_non_draft_status_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet, status="approved")
        errors = rs.validate_contract(contract)
        self.assertTrue(any("'draft'" in e for e in errors), errors)

    def test_unresolved_prerequisite_blocks_supported_claim(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet, capability_claim="supported")
        errors = rs.validate_contract(contract)
        self.assertTrue(
            any("block a supported-capability claim" in e for e in errors), errors
        )

    def test_discovery_cannot_claim_supported_capability(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet, capability_claim="supported")
        contract["prerequisites"] = [
            {"id": "p", "description": "All verified.", "status": "verified"}
        ]
        errors = rs.validate_contract(contract)
        self.assertTrue(any("discovery experiment" in e for e in errors), errors)

    def test_discovery_needs_explicit_uncertainty(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        del contract["uncertainty"]
        errors = rs.validate_contract(contract)
        self.assertTrue(any("uncertainty" in e for e in errors), errors)

    def test_supported_claim_needs_packet_evidence_check(self):
        # Shape-level: a supported claim with no --packet must be refused.
        proc = run_cli(
            "contract-validate", str(EXAMPLE_CONTRACT),
        )
        # The example itself is unsupported, so it passes; craft a supported one.
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet, capability_claim="supported")
        contract["experiment_type"] = "capability"
        contract["prerequisites"] = [
            {"id": "p", "description": "Verified.", "status": "verified"}
        ]
        del contract["uncertainty"]
        root = slice_a.make_temp_root(self)
        path = root / "supported.json"
        path.write_text(json.dumps(contract), encoding="utf-8")
        proc = run_cli("contract-validate", str(path))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("--packet", proc.stdout + proc.stderr)


class ContractRefTests(unittest.TestCase):
    def test_known_refs_accepted_against_packet(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        self.assertEqual(rs.check_contract_refs(contract, packet), [])

    def test_dangling_ref_rejected(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        contract["computer_evidence"][0]["observation_id"] = "no-such-observation"
        errors = rs.check_contract_refs(contract, packet)
        self.assertTrue(any("dangling observation ref" in e for e in errors), errors)

    def test_service_existence_only_cannot_claim_usefulness(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(
            self,
            services=[{"id": "svc", "unit": "fixture.service", "manager": "system"}],
        )
        service_obs = [o for o in packet["observations"] if o["kind"] == "service"]
        self.assertTrue(service_obs, "fixture needs a service observation")
        contract = make_contract(packet, capability_claim="supported")
        contract["experiment_type"] = "capability"
        contract["prerequisites"] = [
            {"id": "p", "description": "Verified.", "status": "verified"}
        ]
        del contract["uncertainty"]
        contract["computer_evidence"] = [
            {
                "description": "Service exists, therefore useful (invalid).",
                "observation_id": service_obs[0]["id"],
            }
        ]
        errors = rs.check_contract_refs(contract, packet)
        self.assertTrue(
            any("declared-only service existence" in e for e in errors), errors
        )

    def test_supported_claim_with_outcome_evidence_passes_refs(self):
        _, _, _, _, _, _, packet = slice_a.collect_fixture(
            self,
            services=[{"id": "svc", "unit": "fixture.service", "manager": "system"}],
        )
        outcome_obs = [o for o in packet["observations"] if o["kind"] == "outcome"]
        self.assertTrue(outcome_obs, "fixture needs an outcome observation")
        service_obs = [o for o in packet["observations"] if o["kind"] == "service"]
        contract = make_contract(packet, capability_claim="supported")
        contract["experiment_type"] = "capability"
        contract["prerequisites"] = [
            {"id": "p", "description": "Verified.", "status": "verified"}
        ]
        del contract["uncertainty"]
        contract["computer_evidence"] = [
            {"description": "Outcome record.", "observation_id": outcome_obs[0]["id"]},
            {"description": "Service availability.", "observation_id": service_obs[0]["id"]},
        ]
        self.assertEqual(rs.validate_contract(contract), [])
        self.assertEqual(rs.check_contract_refs(contract, packet), [])


class StorageCliTests(unittest.TestCase):
    def write_record(self, root: Path, record: dict, name: str) -> Path:
        path = root / name
        path.write_text(json.dumps(record), encoding="utf-8")
        return path

    def write_packet(self, root: Path, packet: dict) -> Path:
        path = root / "packet.json"
        path.write_text(json.dumps(packet), encoding="utf-8")
        return path

    def test_salience_store_persists_private_immutable_pair(self):
        root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        record = make_salience(packet)
        record_path = self.write_record(root, record, "salience.json")
        packet_path = self.write_packet(root, packet)
        state = root / "state"
        proc = run_cli(
            "salience-store", str(record_path),
            "--state-dir", str(state), "--packet", str(packet_path),
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        stored = sorted(state.glob("salience-*.json"))
        self.assertEqual(len(stored), 1)
        self.assertEqual(stat.S_IMODE(stored[0].stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(state.stat().st_mode), 0o700)
        before = stored[0].read_bytes()
        md = stored[0].with_suffix(".md")
        self.assertTrue(md.exists())
        self.assertIn(record["salience_id"], md.read_text(encoding="utf-8"))
        # Immutable: a second store lands on a new unique path; first untouched.
        proc2 = run_cli(
            "salience-store", str(record_path),
            "--state-dir", str(state), "--packet", str(packet_path),
        )
        self.assertEqual(proc2.returncode, 0, proc2.stdout + proc2.stderr)
        self.assertEqual(len(sorted(state.glob("salience-*.json"))), 2)
        self.assertEqual(stored[0].read_bytes(), before)

    def test_contract_store_marks_draft_not_authorization(self):
        root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        contract_path = self.write_record(root, contract, "contract.json")
        state = root / "state"
        proc = run_cli("contract-store", str(contract_path), "--state-dir", str(state))
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        stored = sorted(state.glob("contract-*.json"))
        self.assertEqual(len(stored), 1)
        self.assertIn("NOT authorization", proc.stdout)
        md = stored[0].with_suffix(".md")
        self.assertIn("DRAFT", md.read_text(encoding="utf-8"))

    def test_invalid_records_refused_without_storage(self):
        root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        contract = make_contract(packet)
        del contract["counterexample"]
        contract_path = self.write_record(root, contract, "bad.json")
        state = root / "state"
        proc = run_cli("contract-store", str(contract_path), "--state-dir", str(state))
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        self.assertFalse(state.exists() and list(state.glob("*.json")))

        bad_salience = make_salience(packet, status="no_candidate", candidates=[])
        salience_path = self.write_record(root, bad_salience, "bad-sal.json")
        proc2 = run_cli(
            "salience-validate", str(salience_path),
        )
        self.assertEqual(proc2.returncode, 1, proc2.stdout + proc2.stderr)

    def test_validate_commands_accept_good_inputs(self):
        root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        packet_path = self.write_packet(root, packet)
        salience_path = self.write_record(root, make_salience(packet), "s.json")
        contract_path = self.write_record(root, make_contract(packet), "c.json")
        for args in (
            ("salience-validate", str(salience_path), "--packet", str(packet_path)),
            ("contract-validate", str(contract_path), "--packet", str(packet_path)),
            ("salience-validate", str(salience_path)),
            ("contract-validate", str(contract_path)),
            ("contract-validate", str(EXAMPLE_CONTRACT)),
        ):
            proc = run_cli(*args)
            self.assertEqual(proc.returncode, 0, f"{args}: {proc.stdout}{proc.stderr}")

    def test_example_fixture_needs_relink_against_real_packet(self):
        # The example's packet_id names no live packet: ref-check must refuse
        # to treat it as evidence for a real packet until re-linked.
        root = slice_a.make_temp_root(self)
        _, _, _, _, _, _, packet = slice_a.collect_fixture(self)
        packet_path = self.write_packet(root, packet)
        contract = json.loads(EXAMPLE_CONTRACT.read_text(encoding="utf-8"))
        contract_path = self.write_record(root, contract, "example.json")
        proc = run_cli(
            "contract-validate", str(contract_path), "--packet", str(packet_path)
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("does not match", proc.stdout + proc.stderr)


class SkillPackagingTests(unittest.TestCase):
    def test_linkfarm_wires_research_state_skill(self):
        text = SKILLS_DEFAULT_NIX.read_text(encoding="utf-8")
        self.assertIn("research/research-state/SKILL.md", text)
        self.assertTrue(SKILL_MD.exists(), f"missing skill source: {SKILL_MD}")

    def test_skill_documents_slice_b_workflow(self):
        text = SKILL_MD.read_text(encoding="utf-8")
        for expected in (
            "salience-store",
            "salience-validate",
            "contract-store",
            "contract-validate",
            "counterexample",
            "no_candidate",
            "human gate",
            "discovery",
        ):
            self.assertIn(expected, text, f"skill must document {expected!r}")
        lowered = text.lower()
        self.assertIn("no automatic", lowered + "no auto", "skill must disclaim generation")
        self.assertIn("never execute", lowered)

    def test_skill_disclaims_auto_generator(self):
        text = SKILL_MD.read_text(encoding="utf-8").lower()
        self.assertTrue(
            ("no automatic candidate generator" in text)
            or ("no candidate generator" in text)
            or ("never auto-generate" in text)
            or ("supplied records only" in text),
            "skill must state there is no auto-generator",
        )


if __name__ == "__main__":
    unittest.main()

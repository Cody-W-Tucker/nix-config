#!/usr/bin/env python3
"""Tests for enrollment revision contract.

Verifies:
- Initial revision is 0
- add_sample increments revision atomically
- Legacy enrollments without revision migrate safely
- Failed add_sample does not increment revision
- Status/inventory endpoints expose revision
"""

import json
import tempfile
from pathlib import Path
import sys
import importlib.util

# Load the server module dynamically (it has a hyphen in the filename)
server_path = Path(__file__).parent / "diarization-server.py"
spec = importlib.util.spec_from_file_location("diarization_server", server_path)
server_module = importlib.util.module_from_spec(spec)

# Mock numpy before loading the module
class MockNDArray:
    def __init__(self, data):
        self.data = data if isinstance(data, list) else list(data)
        self.shape = (len(self.data),)
    
    def tolist(self):
        return self.data

def mock_randn(*shape):
    """Mock numpy.random.randn - returns a list of small values."""
    size = shape[0] if shape else 192
    return MockNDArray([0.1] * size)

def mock_norm(x):
    """Mock numpy.linalg.norm - returns 1.0 for normalized vectors."""
    return 1.0

# Inject mock numpy
import unittest.mock as mock
numpy_mock = mock.MagicMock()
numpy_mock.random.randn = mock_randn
numpy_mock.linalg.norm = mock_norm
numpy_mock.ndarray = MockNDArray
numpy_mock.float32 = float
numpy_mock.array = lambda x: MockNDArray(x if isinstance(x, list) else list(x))
sys.modules['numpy'] = numpy_mock

# Now load the server module
spec.loader.exec_module(server_module)

EnrollmentStore = server_module.EnrollmentStore
MIN_ENROLLMENT_SAMPLES = server_module.MIN_ENROLLMENT_SAMPLES


def test_initial_revision_is_zero():
    """New enrollment initializes with revision=0."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = EnrollmentStore(Path(tmpdir))
        metadata = store.initialize_enrollment(
            person_id="person-test",
            display_name="Test Person",
            consent_granted=True,
        )
        
        assert "revision" in metadata, "Metadata must include revision field"
        assert metadata["revision"] == 0, f"Initial revision must be 0, got {metadata['revision']}"
        assert metadata["samples_count"] == 0
        assert metadata["candidate_eligible"] is False
        print("✓ test_initial_revision_is_zero passed")


def test_add_sample_increments_revision():
    """Each successful add_sample increments revision by 1."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = EnrollmentStore(Path(tmpdir))
        store.initialize_enrollment(
            person_id="person-test",
            display_name="Test Person",
            consent_granted=True,
        )
        
        # Add first sample
        embedding1 = MockNDArray([0.1] * 192)
        metadata1 = store.add_sample("person-test", embedding1)
        
        assert metadata1["revision"] == 1, f"After 1st sample, revision must be 1, got {metadata1['revision']}"
        assert metadata1["samples_count"] == 1
        
        # Add second sample
        embedding2 = MockNDArray([0.2] * 192)
        metadata2 = store.add_sample("person-test", embedding2)
        
        assert metadata2["revision"] == 2, f"After 2nd sample, revision must be 2, got {metadata2['revision']}"
        assert metadata2["samples_count"] == 2
        
        # Add third sample (reaches candidate eligibility)
        embedding3 = MockNDArray([0.3] * 192)
        metadata3 = store.add_sample("person-test", embedding3)
        
        assert metadata3["revision"] == 3, f"After 3rd sample, revision must be 3, got {metadata3['revision']}"
        assert metadata3["samples_count"] == 3
        assert metadata3["candidate_eligible"] is True
        print("✓ test_add_sample_increments_revision passed")


def test_legacy_enrollment_migrates_to_revision_zero():
    """Existing enrollment without revision field is treated as revision 0."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = EnrollmentStore(Path(tmpdir))
        
        # Manually create a legacy enrollment (no revision field)
        person_dir = Path(tmpdir) / "person-test"
        person_dir.mkdir()
        
        legacy_metadata = {
            "person_id": "person-test",
            "display_name": "Test Person",
            "consent_granted": True,
            "consent_timestamp": "2026-01-01T00:00:00+00:00",
            "samples_count": 2,
            "candidate_eligible": False,
            "created_at": "2026-01-01T00:00:00+00:00",
            # No "revision" field
        }
        
        (person_dir / "metadata.json").write_text(json.dumps(legacy_metadata))
        # Legacy has 2 embeddings already
        (person_dir / "embeddings.json").write_text(json.dumps({"embeddings": [[0.1]*192, [0.2]*192]}))
        
        # get_metadata should normalize to revision 0
        metadata = store.get_metadata("person-test")
        assert metadata is not None
        assert metadata["revision"] == 0, f"Legacy enrollment must default to revision 0, got {metadata.get('revision')}"
        
        # add_sample should bump to revision 1
        embedding = MockNDArray([0.1] * 192)
        updated = store.add_sample("person-test", embedding)
        
        assert updated["revision"] == 1, f"After add_sample on legacy, revision must be 1, got {updated['revision']}"
        assert updated["samples_count"] == 3, f"After adding to 2 existing, samples_count must be 3, got {updated['samples_count']}"
        print("✓ test_legacy_enrollment_migrates_to_revision_zero passed")


def test_get_metadata_always_returns_revision():
    """get_metadata always returns a revision field, even for legacy enrollments."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = EnrollmentStore(Path(tmpdir))
        
        # Create enrollment with revision
        store.initialize_enrollment(
            person_id="person-with-revision",
            display_name="With Revision",
            consent_granted=True,
        )
        
        metadata = store.get_metadata("person-with-revision")
        assert "revision" in metadata
        assert metadata["revision"] == 0
        
        # Create legacy enrollment without revision
        person_dir = Path(tmpdir) / "person-legacy"
        person_dir.mkdir()
        legacy_metadata = {
            "person_id": "person-legacy",
            "display_name": "Legacy",
            "consent_granted": True,
            "samples_count": 0,
            "candidate_eligible": False,
        }
        (person_dir / "metadata.json").write_text(json.dumps(legacy_metadata))
        (person_dir / "embeddings.json").write_text(json.dumps({"embeddings": []}))
        
        metadata = store.get_metadata("person-legacy")
        assert "revision" in metadata, "get_metadata must always return revision field"
        assert metadata["revision"] == 0
        print("✓ test_get_metadata_always_returns_revision passed")


def test_list_candidates_includes_revision():
    """list_candidates returns revision for each candidate."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = EnrollmentStore(Path(tmpdir))
        
        # Create and populate an enrollment to candidate-eligible
        store.initialize_enrollment(
            person_id="person-test",
            display_name="Test Person",
            consent_granted=True,
        )
        
        for i in range(MIN_ENROLLMENT_SAMPLES):
            embedding = MockNDArray([0.1 * (i+1)] * 192)
            store.add_sample("person-test", embedding)
        
        candidates = store.list_candidates()
        assert len(candidates) == 1
        assert candidates[0]["person_id"] == "person-test"
        assert "revision" in candidates[0], "list_candidates must include revision"
        assert candidates[0]["revision"] == MIN_ENROLLMENT_SAMPLES
        print("✓ test_list_candidates_includes_revision passed")


def test_list_persons_includes_revision():
    """list_persons returns revision for each person."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = EnrollmentStore(Path(tmpdir))
        
        store.initialize_enrollment(
            person_id="person-test",
            display_name="Test Person",
            consent_granted=True,
        )
        
        persons = store.list_persons()
        assert len(persons) == 1
        assert "revision" in persons[0], "list_persons must include revision"
        assert persons[0]["revision"] == 0
        print("✓ test_list_persons_includes_revision passed")


def test_failed_add_sample_does_not_increment_revision():
    """If add_sample fails (e.g., enrollment not found), revision is not incremented."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = EnrollmentStore(Path(tmpdir))
        store.initialize_enrollment(
            person_id="person-test",
            display_name="Test Person",
            consent_granted=True,
        )
        
        # Try to add sample to non-existent enrollment
        embedding = MockNDArray([0.1] * 192)
        
        try:
            store.add_sample("person-nonexistent", embedding)
            assert False, "Should have raised RuntimeError"
        except RuntimeError:
            pass
        
        # Original enrollment should still have revision 0
        metadata = store.get_metadata("person-test")
        assert metadata["revision"] == 0
        print("✓ test_failed_add_sample_does_not_increment_revision passed")


if __name__ == "__main__":
    print("Running enrollment revision tests...\n")
    
    test_initial_revision_is_zero()
    test_add_sample_increments_revision()
    test_legacy_enrollment_migrates_to_revision_zero()
    test_get_metadata_always_returns_revision()
    test_list_candidates_includes_revision()
    test_list_persons_includes_revision()
    test_failed_add_sample_does_not_increment_revision()
    
    print("\n✅ All server revision tests passed")

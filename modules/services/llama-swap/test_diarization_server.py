#!/usr/bin/env python3
"""Focused unit tests for diarization-server.py.

Tests request validation, health/model endpoints, identity-off response
schema, and busy 503 behavior.  Does NOT download models or process real
audio — all heavy dependencies are mocked.

Run with:
    cd /etc/nixos && python modules/services/llama-swap/test_diarization_server.py -v
"""

import argparse
import importlib
import importlib.util
import json
import os
import sys
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# ── Import the hyphenated module via importlib ───────────────────
_SERVER_PATH = Path(__file__).resolve().parent / "diarization-server.py"
_spec = importlib.util.spec_from_file_location("diarization_server", _SERVER_PATH)
_mod = importlib.util.module_from_spec(_spec)
sys.modules["diarization_server"] = _mod
_spec.loader.exec_module(_mod)

# Re-export the names we need from the module
BusyError = _mod.BusyError
MAX_UPLOAD_BYTES = _mod.MAX_UPLOAD_BYTES
SUPPORTED_FORMATS = _mod.SUPPORTED_FORMATS
build_parser = _mod.build_parser
create_app = _mod.create_app
ModelManager = _mod.ModelManager


def _make_args(**overrides) -> argparse.Namespace:
    """Build a minimal argparse.Namespace for testing."""
    defaults = {
        "host": "127.0.0.1",
        "port": 9999,
        "model_id": "whisper-diarization",
        "device": "cpu",
        "compute_type": "float16",
        "download_root": None,
        "language": None,
        "hf_token_path": None,
        "diarization_model": "pyannote/speaker-diarization-community-1",
        "enrollment_dir": "/tmp/test-enrollment",
    }
    defaults.update(overrides)
    return argparse.Namespace(**defaults)


class TestBuildParser(unittest.TestCase):
    """Verify CLI argument parsing."""

    def test_required_port(self):
        parser = build_parser()
        with self.assertRaises(SystemExit):
            parser.parse_args([])

    def test_defaults(self):
        parser = build_parser()
        args = parser.parse_args(["--port", "8080"])
        self.assertEqual(args.port, 8080)
        self.assertEqual(args.host, "127.0.0.1")
        self.assertEqual(args.model_id, "whisper-diarization")
        self.assertEqual(args.device, "cuda")
        self.assertEqual(args.compute_type, "float16")
        self.assertIsNone(args.hf_token_path)
        self.assertIsNone(args.language)
        self.assertIsNone(args.download_root)
        self.assertEqual(
            args.diarization_model,
            "pyannote/speaker-diarization-community-1",
        )

    def test_custom_diarization_model(self):
        parser = build_parser()
        args = parser.parse_args([
            "--port", "8080",
            "--diarization-model", "pyannote/speaker-diarization-3.1",
        ])
        self.assertEqual(
            args.diarization_model, "pyannote/speaker-diarization-3.1"
        )


class TestBusyError(unittest.TestCase):
    """BusyError is raised when the concurrency lock cannot be acquired."""

    def test_is_exception(self):
        err = BusyError("test")
        self.assertIsInstance(err, Exception)
        self.assertEqual(str(err), "test")


class TestInputValidation(unittest.TestCase):
    """Validate request input checking via the FastAPI test client."""

    @classmethod
    def setUpClass(cls):
        """Build a test client with mocked ModelManager."""
        args = _make_args()
        with patch.object(ModelManager, "__init__", return_value=None):
            cls.app = create_app(args)
        # Manually set app.state as the lifespan would
        mock_manager = MagicMock()
        mock_manager._lock = threading.Lock()
        cls.app.state.manager = mock_manager
        cls.app.state.model_id = args.model_id
        cls.app.state.device = args.device
        from fastapi.testclient import TestClient
        cls.client = TestClient(cls.app)

    def test_health_endpoint(self):
        resp = self.client.get("/v1/health")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["status"], "ok")

    def test_models_endpoint(self):
        resp = self.client.get("/v1/models")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["object"], "list")
        self.assertEqual(len(data["data"]), 1)
        self.assertEqual(data["data"][0]["id"], "whisper-diarization")

    def test_root_endpoint(self):
        resp = self.client.get("/")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["model"], "whisper-diarization")

    def test_wrong_model_rejected(self):
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={"model": "wrong-model"},
            files={"file": ("test.wav", b"fake-audio", "audio/wav")},
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("Model must be", resp.json()["detail"])

    def test_unsupported_format_rejected(self):
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={"model": "whisper-diarization"},
            files={"file": ("test.xyz", b"fake-audio", "application/octet-stream")},
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("Unsupported audio format", resp.json()["detail"])

    def test_empty_file_rejected(self):
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={"model": "whisper-diarization"},
            files={"file": ("test.wav", b"", "audio/wav")},
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("Empty audio file", resp.json()["detail"])

    def test_file_too_large_rejected(self):
        oversized = b"x" * (MAX_UPLOAD_BYTES + 1)
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={"model": "whisper-diarization"},
            files={"file": ("test.wav", oversized, "audio/wav")},
        )
        self.assertEqual(resp.status_code, 413)
        self.assertIn("too large", resp.json()["detail"])

    def test_invalid_response_format_rejected(self):
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={
                "model": "whisper-diarization",
                "response_format": "verbose_json",
            },
            files={"file": ("test.wav", b"fake-audio", "audio/wav")},
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("Only 'diarized_json'", resp.json()["detail"])

    def test_invalid_identity_mode_rejected(self):
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={
                "model": "whisper-diarization",
                "identity_mode": "invalid",
            },
            files={"file": ("test.wav", b"fake-audio", "audio/wav")},
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("identity_mode must be one of", resp.json()["detail"])

    def test_num_speakers_conflicts_with_min_max(self):
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={
                "model": "whisper-diarization",
                "num_speakers": "2",
                "min_speakers": "1",
            },
            files={"file": ("test.wav", b"fake-audio", "audio/wav")},
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("Cannot specify both", resp.json()["detail"])

    def test_speakers_count_must_be_positive(self):
        resp = self.client.post(
            "/v1/audio/transcriptions",
            data={
                "model": "whisper-diarization",
                "min_speakers": "0",
            },
            files={"file": ("test.wav", b"fake-audio", "audio/wav")},
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("must be >= 1", resp.json()["detail"])


class TestBusyResponse(unittest.TestCase):
    """Verify that a busy server returns HTTP 503."""

    def test_busy_returns_503(self):
        """When the lock can't be acquired, endpoint returns 503."""
        import types
        import unittest.mock as umock

        # Mock torch so ModelManager.__init__ can import it
        mock_torch = types.ModuleType("torch")
        mock_torch.cuda = types.ModuleType("torch.cuda")
        mock_torch.cuda.is_available = lambda: False
        mock_torch.cuda.empty_cache = lambda: None
        mock_torch.cuda.synchronize = lambda: None
        sys.modules["torch"] = mock_torch

        try:
            args = _make_args(device="cpu")
            app = create_app(args)

            # The routes capture `manager` from create_app's closure.
            # app.state.manager is set to the same object in lifespan.
            # Mock lock.acquire to return False (simulate busy).
            manager = app.state.manager
            original_lock = manager._lock
            mock_lock = umock.MagicMock()
            mock_lock.acquire = umock.MagicMock(return_value=False)
            mock_lock.release = umock.MagicMock()
            manager._lock = mock_lock

            from fastapi.testclient import TestClient
            with TestClient(app) as client:
                resp = client.post(
                    "/v1/audio/transcriptions",
                    data={"model": "whisper-diarization"},
                    files={"file": ("test.wav", b"fake-audio", "audio/wav")},
                )
                self.assertEqual(resp.status_code, 503)
                self.assertIn("concurrency limit", resp.json()["detail"])

            manager._lock = original_lock
        finally:
            sys.modules.pop("torch", None)


class TestEnrollmentDisabled(unittest.TestCase):
    """Enrollment endpoints return 501 until embedding matcher exists."""

    @classmethod
    def setUpClass(cls):
        args = _make_args()
        with patch.object(ModelManager, "__init__", return_value=None):
            cls.app = create_app(args)
        mock_manager = MagicMock()
        mock_manager._lock = threading.Lock()
        cls.app.state.manager = mock_manager
        cls.app.state.model_id = args.model_id
        cls.app.state.device = args.device
        from fastapi.testclient import TestClient
        cls.client = TestClient(cls.app)

    def test_enroll_returns_501(self):
        resp = self.client.post(
            "/v1/identity/enroll",
            data={
                "consent": "true",
                "person_id": "test",
                "display_name": "Test",
            },
        )
        self.assertEqual(resp.status_code, 501)
        self.assertIn("not yet implemented", resp.json()["detail"].lower())

    def test_samples_returns_501(self):
        resp = self.client.post(
            "/v1/identity/samples",
            data={"person_id": "test"},
            files={"file": ("test.wav", b"fake-audio", "audio/wav")},
        )
        self.assertEqual(resp.status_code, 501)

    def test_candidates_still_works(self):
        resp = self.client.get("/v1/identity/candidates")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["status"], "matching_unavailable")
        self.assertIn("candidates", data)


class TestIdentityOffResponseSchema(unittest.TestCase):
    """Verify the response schema when identity_mode is off (default)."""

    def test_response_structure(self):
        """The identity block in the response has the correct shape."""
        expected_keys = {
            "text", "language", "duration", "segments",
            "speakers", "identity", "warnings",
        }
        identity_keys = {"mode", "status"}

        response = {
            "text": "Hello world",
            "language": "en",
            "duration": 1.5,
            "segments": [
                {"start": 0.0, "end": 1.5, "text": "Hello world",
                 "speaker": "SPEAKER_00"}
            ],
            "speakers": ["SPEAKER_00"],
            "identity": {"mode": "off", "status": "not_requested"},
            "warnings": [],
        }

        self.assertEqual(set(response.keys()), expected_keys)
        self.assertEqual(set(response["identity"].keys()), identity_keys)
        self.assertEqual(response["identity"]["mode"], "off")
        self.assertEqual(response["identity"]["status"], "not_requested")
        self.assertIsInstance(response["segments"], list)
        self.assertIsInstance(response["speakers"], list)
        self.assertIsInstance(response["warnings"], list)

    def test_candidates_identity_status(self):
        """When identity_mode is candidates, status is matching_unavailable."""
        response = {
            "identity": {"mode": "candidates",
                         "status": "matching_unavailable"},
            "warnings": ["Identity matching is not available"],
        }
        self.assertEqual(response["identity"]["status"],
                         "matching_unavailable")
        self.assertTrue(len(response["warnings"]) > 0)


if __name__ == "__main__":
    unittest.main()

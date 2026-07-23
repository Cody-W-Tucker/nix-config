"""Tests for SpeechBrain EmbeddingExtractor initialization compatibility.

Verifies that the embedding extractor:
- Does not pass unsupported keyword arguments (notably ``token``) to
  ``EncoderClassifier.from_hparams``, which would cause a ``TypeError``
  under SpeechBrain 1.1.
- Uses auto device selection (CUDA if available, else CPU).
- Disables MKLDNN only on CPU path.
- Falls back to CPU on CUDA init/forward device errors.
- Does not fall back on data/segment errors.

These tests use mocking to avoid loading the actual model.
"""
import importlib.util
import sys
import pytest
from unittest.mock import MagicMock, patch, call


def _load_diarization_server():
    """Load diarization-server.py (hyphenated filename) via importlib.

    Mocks heavy dependencies (fastapi, uvicorn, numpy) that aren't
    needed for these unit tests.
    """
    # Remove cached module if present to pick up edits
    sys.modules.pop("diarization_server", None)

    # Mock heavy dependencies before loading the module
    for mod_name in ["numpy", "uvicorn", "fastapi", "fastapi.responses"]:
        if mod_name not in sys.modules:
            sys.modules[mod_name] = MagicMock()

    # numpy needs some attributes for the import to succeed
    np_mock = sys.modules["numpy"]
    np_mock.ndarray = type("ndarray", (), {})
    # Provide a working linalg.norm that handles real numpy arrays
    import numpy as _real_np
    np_mock.linalg = MagicMock()
    np_mock.linalg.norm = lambda x: _real_np.linalg.norm(x) if isinstance(x, _real_np.ndarray) else 1.0

    spec = importlib.util.spec_from_file_location(
        "diarization_server",
        "/etc/nixos/modules/services/llama-swap/diarization-server.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _make_mock_torch(cuda_available=False):
    """Create a mock torch module with configurable CUDA availability."""
    mock_torch = MagicMock()
    mock_torch.cuda.is_available.return_value = cuda_available
    mock_torch.cuda.empty_cache = MagicMock()
    mock_torch.cuda.synchronize = MagicMock()
    return mock_torch


def _make_mock_mkldnn():
    """Create a mock mkldnn module."""
    mock_mkldnn = MagicMock()
    mock_mkldnn.enabled = True
    return mock_mkldnn


def _make_mock_sb():
    """Create a mock SpeechBrain module with a controllable classifier."""
    mock_classifier_class = MagicMock()
    mock_classifier_instance = MagicMock()
    mock_classifier_class.from_hparams.return_value = mock_classifier_instance
    mock_sb_speaker = MagicMock()
    mock_sb_speaker.EncoderClassifier = mock_classifier_class
    return mock_sb_speaker, mock_classifier_class, mock_classifier_instance


# ── Original compatibility tests ──────────────────────────────────────────


def test_embedding_extractor_no_hf_token_parameter():
    """EmbeddingExtractor constructor must not accept hf_token.

    The model is public; no authentication is needed.  The constructor
    signature should not include an hf_token parameter.
    """
    ds = _load_diarization_server()

    import inspect
    sig = inspect.signature(ds.EmbeddingExtractor.__init__)
    params = list(sig.parameters.keys())

    assert params == ["self"], (
        f"EmbeddingExtractor.__init__ should only accept 'self', "
        f"got {params}. The model is public and does not require authentication."
    )


def test_embedding_extractor_from_hparams_no_token():
    """_ensure_model must not pass token= to from_hparams.

    SpeechBrain 1.1's Pretrained.__init__ does not accept a ``token``
    keyword argument.
    """
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    mock_torch = _make_mock_torch(cuda_available=False)
    mock_mkldnn = _make_mock_mkldnn()

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        extractor._ensure_model()

    call_args = mock_cls.from_hparams.call_args
    assert "token" not in (call_args.kwargs or {}), (
        "from_hparams must not receive 'token' keyword argument."
    )
    assert call_args.kwargs["source"] == "speechbrain/spkrec-ecapa-voxceleb"
    assert "run_opts" in call_args.kwargs


def test_embedding_extractor_model_id():
    """EmbeddingExtractor should use the public ECAPA model."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()
    assert extractor._model_id == "speechbrain/spkrec-ecapa-voxceleb"


def test_embedding_extractor_no_token_attribute():
    """EmbeddingExtractor should not store an hf_token attribute."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()
    assert not hasattr(extractor, "_hf_token"), (
        "EmbeddingExtractor should not have _hf_token attribute."
    )


# ── Auto device selection tests ───────────────────────────────────────────


def test_auto_selects_cuda_when_available():
    """When CUDA is available, _ensure_model should load on CUDA."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    mock_torch = _make_mock_torch(cuda_available=True)
    mock_mkldnn = _make_mock_mkldnn()

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        extractor._ensure_model()

    call_args = mock_cls.from_hparams.call_args
    assert call_args.kwargs["run_opts"]["device"] == "cuda", (
        "Should select CUDA when torch.cuda.is_available() is True"
    )
    assert extractor._device == "cuda"


def test_auto_selects_cpu_when_cuda_unavailable():
    """When CUDA is not available, _ensure_model should load on CPU."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    mock_torch = _make_mock_torch(cuda_available=False)
    mock_mkldnn = _make_mock_mkldnn()

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        extractor._ensure_model()

    call_args = mock_cls.from_hparams.call_args
    assert call_args.kwargs["run_opts"]["device"] == "cpu", (
        "Should select CPU when torch.cuda.is_available() is False"
    )
    assert extractor._device == "cpu"


# ── MKLDNN scoping tests ─────────────────────────────────────────────────


def test_mkldnn_disabled_on_cpu_path():
    """MKLDNN must be disabled when loading on CPU."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    mock_torch = _make_mock_torch(cuda_available=False)
    mock_mkldnn = _make_mock_mkldnn()
    mock_mkldnn.enabled = True
    # Wire the import traversal: `import torch.backends.mkldnn as _mkldnn`
    # resolves via attribute chain, so the mock must be reachable from torch.
    mock_torch.backends.mkldnn = mock_mkldnn

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        extractor._ensure_model()

    assert mock_mkldnn.enabled is False, (
        "MKLDNN must be disabled on CPU path for systemd MemoryDenyWriteExecute"
    )


def test_mkldnn_not_disabled_on_cuda_path():
    """MKLDNN must NOT be disabled when loading on CUDA."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    mock_torch = _make_mock_torch(cuda_available=True)
    mock_mkldnn = _make_mock_mkldnn()
    mock_mkldnn.enabled = True

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        extractor._ensure_model()

    assert mock_mkldnn.enabled is True, (
        "MKLDNN should NOT be disabled on CUDA path"
    )


# ── CUDA fallback tests ──────────────────────────────────────────────────


def test_cuda_init_failure_falls_back_to_cpu():
    """When CUDA init fails with a device error, fall back to CPU."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    # First call (CUDA) raises RuntimeError, second call (CPU) succeeds
    mock_cls.from_hparams.side_effect = [
        RuntimeError("CUDA out of memory"),
        mock_inst,
    ]
    mock_torch = _make_mock_torch(cuda_available=True)
    mock_mkldnn = _make_mock_mkldnn()

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        extractor._ensure_model()

    # Should have been called twice: CUDA then CPU
    assert mock_cls.from_hparams.call_count == 2
    first_call_device = mock_cls.from_hparams.call_args_list[0].kwargs["run_opts"]["device"]
    second_call_device = mock_cls.from_hparams.call_args_list[1].kwargs["run_opts"]["device"]
    assert first_call_device == "cuda"
    assert second_call_device == "cpu"
    assert extractor._device == "cpu"
    assert extractor._cuda_fallback_used is True


def test_cuda_init_failure_non_device_error_no_fallback():
    """Non-device errors during CUDA init should NOT trigger CPU fallback."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    mock_cls.from_hparams.side_effect = RuntimeError("Network timeout downloading model")
    mock_torch = _make_mock_torch(cuda_available=True)
    mock_mkldnn = _make_mock_mkldnn()

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        with pytest.raises(RuntimeError, match="initialization failed"):
            extractor._ensure_model()

    # Should have been called only once (no fallback)
    assert mock_cls.from_hparams.call_count == 1
    assert extractor._model is None


def test_cuda_forward_failure_falls_back_to_cpu():
    """When CUDA forward pass fails with device error, fall back to CPU."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    # Pre-load model as if it was already on CUDA
    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    extractor._model = mock_inst
    extractor._device = "cuda"
    extractor._cuda_fallback_used = False

    mock_torch = _make_mock_torch(cuda_available=True)
    mock_mkldnn = _make_mock_mkldnn()
    mock_torch.backends.mkldnn = mock_mkldnn

    # After fallback, _ensure_model will be called again; make it succeed on CPU
    # with a model that returns a proper numpy array
    import numpy as real_np
    cpu_mock_inst = MagicMock()
    cpu_embedding = real_np.random.randn(192).astype(real_np.float32)
    cpu_embedding = cpu_embedding / real_np.linalg.norm(cpu_embedding)
    cpu_mock_tensor = MagicMock()
    cpu_mock_tensor.squeeze.return_value.cpu.return_value.numpy.return_value = cpu_embedding
    cpu_mock_inst.encode_batch.return_value = cpu_mock_tensor
    mock_cls.from_hparams.return_value = cpu_mock_inst

    mock_signal = MagicMock()

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        # First encode_batch call raises, then after fallback it should succeed
        call_count = [0]
        def encode_side_effect(signal):
            call_count[0] += 1
            if call_count[0] == 1:
                raise RuntimeError("CUDA driver error")
            return cpu_mock_tensor

        mock_inst.encode_batch.side_effect = encode_side_effect

        result = extractor._encode_waveform(mock_signal)

    assert extractor._cuda_fallback_used is True
    assert extractor._device == "cpu"
    assert mock_cls.from_hparams.called


def test_cuda_forward_data_error_no_fallback():
    """Data errors during forward pass should NOT trigger CUDA fallback."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    mock_inst.encode_batch.side_effect = RuntimeError("Invalid audio shape")
    extractor._model = mock_inst
    extractor._device = "cuda"
    extractor._cuda_fallback_used = False

    mock_torch = _make_mock_torch(cuda_available=True)
    mock_mkldnn = _make_mock_mkldnn()
    mock_signal = MagicMock()

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        with pytest.raises(RuntimeError, match="Invalid audio shape"):
            extractor._encode_waveform(mock_signal)

    # Should NOT have fallen back
    assert extractor._cuda_fallback_used is False
    assert extractor._device == "cuda"
    assert not mock_cls.from_hparams.called


# ── Short segment logging tests ───────────────────────────────────────────


def test_short_segment_does_not_trigger_cuda_fallback():
    """Short segment errors should not trigger CUDA fallback."""
    ds = _load_diarization_server()
    extractor = ds.EmbeddingExtractor()

    # Set up as if CUDA is loaded
    mock_sb, mock_cls, mock_inst = _make_mock_sb()
    extractor._model = mock_inst
    extractor._device = "cuda"
    extractor._cuda_fallback_used = False

    mock_torch = _make_mock_torch(cuda_available=True)
    mock_mkldnn = _make_mock_mkldnn()

    # Mock torchaudio to return a very short signal that triggers the
    # "segment too short" path. The signal must behave like a tensor
    # under slicing so the code reaches the duration check.
    mock_torchaudio = MagicMock()
    mock_signal = MagicMock()
    # signal.shape[0] == 1 means mono (skip mean(dim=0))
    mock_signal.shape = [1, 100]  # 100 samples at 16kHz = 0.00625s
    # After slicing signal[:, start:end], the segment must report shape[1] < 4800
    mock_segment = MagicMock()
    mock_segment.shape = [1, 100]  # short segment
    mock_signal.__getitem__ = MagicMock(return_value=mock_segment)
    mock_torchaudio.load.return_value = (mock_signal, 16000)

    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "torchaudio": mock_torchaudio,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb,
    }):
        with pytest.raises(RuntimeError, match="Segment too short"):
            extractor.extract_embedding_from_segment("/fake/audio.wav", 0.0, 0.1)

    # Should NOT have fallen back — this is a data error, not device error
    assert extractor._cuda_fallback_used is False
    assert extractor._device == "cuda"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

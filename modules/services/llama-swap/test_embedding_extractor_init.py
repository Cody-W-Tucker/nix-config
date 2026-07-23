"""Tests for SpeechBrain EmbeddingExtractor initialization compatibility.

Verifies that the embedding extractor does not pass unsupported keyword
arguments (notably ``token``) to ``EncoderClassifier.from_hparams``,
which would cause a ``TypeError`` under SpeechBrain 1.1.

These tests use mocking to avoid loading the actual model.
"""
import importlib.util
import sys
import pytest
from unittest.mock import MagicMock, patch


def _load_diarization_server():
    """Load diarization-server.py (hyphenated filename) via importlib.
    
    Mocks heavy dependencies (fastapi, uvicorn, numpy) that aren't
    needed for these unit tests.
    """
    # Mock heavy dependencies before loading the module
    for mod_name in ["numpy", "uvicorn", "fastapi", "fastapi.responses"]:
        if mod_name not in sys.modules:
            sys.modules[mod_name] = MagicMock()
    
    # numpy needs some attributes for the import to succeed
    np_mock = sys.modules["numpy"]
    np_mock.ndarray = type("ndarray", (), {})
    np_mock.linalg = MagicMock()
    
    spec = importlib.util.spec_from_file_location(
        "diarization_server",
        "/etc/nixos/modules/services/llama-swap/diarization-server.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_embedding_extractor_no_hf_token_parameter():
    """EmbeddingExtractor constructor must not accept hf_token.
    
    The model is public; no authentication is needed.  The constructor
    signature should not include an hf_token parameter.
    """
    ds = _load_diarization_server()
    
    # Verify constructor signature does not include hf_token
    import inspect
    sig = inspect.signature(ds.EmbeddingExtractor.__init__)
    params = list(sig.parameters.keys())
    
    # Should only have 'self'
    assert params == ["self"], (
        f"EmbeddingExtractor.__init__ should only accept 'self', "
        f"got {params}. The model is public and does not require authentication."
    )


def test_embedding_extractor_from_hparams_no_token():
    """_ensure_model must not pass token= to from_hparams.
    
    SpeechBrain 1.1's Pretrained.__init__ does not accept a ``token``
    keyword argument. Passing one causes:
        TypeError: Pretrained.__init__() got an unexpected keyword argument 'token'
    """
    ds = _load_diarization_server()
    
    extractor = ds.EmbeddingExtractor()
    
    # Mock the SpeechBrain import and from_hparams
    mock_classifier_class = MagicMock()
    mock_classifier_instance = MagicMock()
    mock_classifier_class.from_hparams.return_value = mock_classifier_instance
    
    # Mock torch and mkldnn
    mock_torch = MagicMock()
    mock_mkldnn = MagicMock()
    mock_mkldnn.enabled = True
    
    mock_sb_speaker = MagicMock()
    mock_sb_speaker.EncoderClassifier = mock_classifier_class
    
    with patch.dict(sys.modules, {
        "torch": mock_torch,
        "torch.backends.mkldnn": mock_mkldnn,
        "speechbrain": MagicMock(),
        "speechbrain.inference": MagicMock(),
        "speechbrain.inference.speaker": mock_sb_speaker,
    }):
        extractor._ensure_model()
    
    # Verify from_hparams was called
    assert mock_classifier_class.from_hparams.called, (
        "EncoderClassifier.from_hparams should have been called"
    )
    
    # Get the call arguments
    call_args = mock_classifier_class.from_hparams.call_args
    
    # Verify no 'token' keyword argument
    if call_args.kwargs:
        assert "token" not in call_args.kwargs, (
            "from_hparams must not receive 'token' keyword argument. "
            "SpeechBrain 1.1 does not support it."
        )
    
    # Verify expected arguments are present
    assert "source" in call_args.kwargs, "from_hparams should receive 'source'"
    assert "run_opts" in call_args.kwargs, "from_hparams should receive 'run_opts'"
    
    # Verify source is the expected model
    assert call_args.kwargs["source"] == "speechbrain/spkrec-ecapa-voxceleb", (
        "source should be the public ECAPA model"
    )
    
    # Verify run_opts specifies CPU
    assert call_args.kwargs["run_opts"]["device"] == "cpu", (
        "run_opts should specify device='cpu'"
    )


def test_embedding_extractor_model_id():
    """EmbeddingExtractor should use the public ECAPA model."""
    ds = _load_diarization_server()
    
    extractor = ds.EmbeddingExtractor()
    assert extractor._model_id == "speechbrain/spkrec-ecapa-voxceleb", (
        "Model ID should be the public ECAPA model"
    )


def test_embedding_extractor_no_token_attribute():
    """EmbeddingExtractor should not store an hf_token attribute."""
    ds = _load_diarization_server()
    
    extractor = ds.EmbeddingExtractor()
    
    # Should not have _hf_token attribute
    assert not hasattr(extractor, "_hf_token"), (
        "EmbeddingExtractor should not have _hf_token attribute. "
        "The model is public and does not require authentication."
    )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

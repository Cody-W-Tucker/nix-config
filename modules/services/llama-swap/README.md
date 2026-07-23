# llama-swap multimodal notes

- Multimodal GGUFs served by `llama-server` need the matching projector GGUF passed with `--mmproj`.
- Download the projector from the same Hugging Face repo or release as the base GGUF.
- Upstream files are often named generically, for example `mmproj-F16.gguf`.
- Rename projector files when storing them in `/srv/llama-swap/models` so multiple model families do not collide.

Recommended local naming pattern:

```text
<model-name>-mmproj-F16.gguf
```

Examples used in this repo:

```text
gemma-3-12b-it-mmproj-F16.gguf
gemma-4-26B-A4B-it-mmproj-F16.gguf
Qwen3.5-35B-A3B-mmproj-F16.gguf
```

If a model accepts image input but `llama-server` returns `image input is not supported`, the usual cause is a missing or mismatched projector file.

## Diarization server: CPU embedding extractor and systemd hardening

The diarization service runs under `MemoryDenyWriteExecute=yes`. This is an intentional sandbox setting — do not weaken it.

The CPU speaker-embedding extractor (`EmbeddingExtractor`) disables `torch.backends.mkldnn.enabled` *before* constructing the SpeechBrain ECAPA model. This is required because oneDNN/MKLDNN JIT primitive creation allocates writable+executable memory pages, which the systemd hardening correctly rejects. The fix is scoped to the lazy CPU initialization path; GPU diarization uses CUDA and is unaffected.

If embedding extraction fails inside the service but works when run directly, this is not an audio or model failure — it is the W^X hardening doing its job. The extractor already disables MKLDNN before model construction. If you see a regression here, check that `torch.backends.mkldnn.enabled` is still set to `False` before `EncoderClassifier.from_hparams` is called.

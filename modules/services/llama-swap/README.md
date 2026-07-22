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

## Diarization server: embedding extractor device policy and systemd hardening

The diarization service runs under `MemoryDenyWriteExecute=yes`. This is an intentional sandbox setting — do not weaken it.

### Speaker embedding extractor: auto CUDA/CPU device policy

The speaker-embedding extractor (`EmbeddingExtractor`) uses an auto device policy: CUDA if `torch.cuda.is_available()` returns True, otherwise CPU. This applies to both enrollment sample extraction and cache-build segment extraction.

**CUDA fallback:** If CUDA model initialization or forward pass fails due to a device/runtime error (CUDA OOM, driver issue, etc.), the extractor logs a warning, cleans up CUDA allocation, and falls back to CPU once. The fallback is permanent for that service instance — it will not retry CUDA. Data errors (corrupt audio, short segments) do not trigger fallback.

**MKLDNN scoping:** `torch.backends.mkldnn.enabled` is set to `False` *only* on the CPU path, before constructing the SpeechBrain ECAPA model. This is required because oneDNN/MKLDNN JIT primitive creation allocates writable+executable memory pages, which the systemd hardening correctly rejects. The CUDA path does not use MKLDNN and is unaffected.

**Concurrency and GPU phases:** The embedding extractor runs after ASR/alignment/diarization phases have unloaded from the GPU. The extractor's internal lock serializes concurrent extraction requests. No overlap with active GPU phases occurs.

### Short segment exclusions are normal

During cache build, segments shorter than 0.3 seconds are excluded from embedding extraction. This is expected behavior — short segments do not produce stable embeddings. The cache build logs these as warning-level exclusions (not errors) and continues with the remaining valid segments. A cache build succeeds as long as at least one label has at least one valid segment. Structured exclusion metadata (count, labels, reasons) is stored in the cache manifest for audit.

If embedding extraction fails inside the service but works when run directly, check whether it is a W^X hardening issue (CPU path must disable MKLDNN) or a CUDA device error (fallback to CPU should occur automatically).

### Speaker embedding model: public, no authentication

The speaker embedding model (`speechbrain/spkrec-ecapa-voxceleb`) is public on Hugging Face. No HF token is passed to `EncoderClassifier.from_hparams`. SpeechBrain 1.1's `Pretrained.__init__` does not accept a `token` keyword argument — passing one causes an immediate `TypeError` at load time. The HF token configured for the service is used only by the WhisperX `DiarizationPipeline` (which does accept `token=`), not by the SpeechBrain embedding extractor.

## Diarization embedding cache directory

The diarization server writes speaker-embedding weights to `/var/lib/llama-swap/diarization/embedding-cache`. This directory is created by `systemd.tmpfiles.rules` in `hosts/beast/models.nix` with the same owner (`codyt:users`) and permissions (`0750`) as the enrollment directory, and is listed in the service's `ReadWritePaths`.

Deploy with:

```console
sudo nixos-rebuild switch
```

Do not create or `chmod` this path manually — the tmpfiles rule owns it. If the service fails with `OSError: [Errno 30] Read-only file system` on this path, the `ReadWritePaths` entry is missing or the tmpfiles rule has not been applied yet.

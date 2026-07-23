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

### Speaker embedding model: public, no authentication

The speaker embedding model (`speechbrain/spkrec-ecapa-voxceleb`) is public on Hugging Face. No HF token is passed to `EncoderClassifier.from_hparams`. SpeechBrain 1.1's `Pretrained.__init__` does not accept a `token` keyword argument — passing one causes an immediate `TypeError` at load time. The HF token configured for the service is used only by the WhisperX `DiarizationPipeline` (which does accept `token=`), not by the SpeechBrain embedding extractor.

## Diarization embedding cache directory

The diarization server writes speaker-embedding weights to `/var/lib/llama-swap/diarization/embedding-cache`. This directory is created by `systemd.tmpfiles.rules` in `hosts/beast/models.nix` with the same owner (`codyt:users`) and permissions (`0750`) as the enrollment directory, and is listed in the service's `ReadWritePaths`.

Deploy with:

```console
sudo nixos-rebuild switch
```

Do not create or `chmod` this path manually — the tmpfiles rule owns it. If the service fails with `OSError: [Errno 30] Read-only file system` on this path, the `ReadWritePaths` entry is missing or the tmpfiles rule has not been applied yet.

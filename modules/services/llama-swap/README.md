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

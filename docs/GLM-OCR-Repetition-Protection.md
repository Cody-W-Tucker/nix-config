# GLM-OCR Repetition Loop Protection

## Problem

The `glm-ocr-f16` model was configured with greedy decoding (`--top-k 1 --temp 0`) but no repetition protection. Paperless-GPT sends OCR requests to this model, and without repeat penalties, the model could enter infinite loops generating the same token sequence until hitting the hard token limit.

## Solution

Added server-side repetition protection to `glm-ocr-f16` in `modules/services/llama-swap/models.nix`:

```nix
extraArgs = [
  "--samplers" "top_k"
  "--top-k" "1"
  "--temp" "0"
  "--repeat-penalty" "1.1"      # NEW: conservative penalty
  "--repeat-last-n" "256"        # NEW: penalty window
  "--cache-type-k" "q8_0"
  "--cache-type-v" "q8_0"
];
```

## Why These Values

- **`--repeat-penalty 1.1`**: Conservative multiplier that discourages pure repetition loops without harming legitimately repeated tokens in OCR output (table borders, dashed lines, repeated characters in formatted text). A value of 1.0 disables the penalty; 1.1 provides just enough bias against repetition.

- **`--repeat-last-n 256`**: Window over which repeated tokens are penalized. Large enough to catch medium-range repetition loops (up to 256 tokens) while leaving short repeated punctuation sequences alone. The default of 64 was too small to catch longer loops.

## What Cannot Be Configured

**Stop sequences**: Paperless-GPT's OCR code (`ocr/llm_provider.go`) uses the `langchaingo/llms` OpenAI client with only `WithModel`/`WithToken` configuration — it does **not** send `stop` sequences in OCR requests. The llama-server has no CLI flag for server-wide default stop sequences; it accepts `stop` only per-request via the OpenAI-compatible API.

**Why this matters**: Without stop sequences, the model cannot be told to halt when it generates a delimiter like ` ``` `. The hard output cap (`VISION_LLM_MAX_TOKENS=2048` on the Paperless-GPT side) remains the last-resort bound on runaway generation.

**Evidence**: 
- llama-server `--help` shows no `--stop` flag
- Paperless-GPT source (`ocr/llm_provider.go`) creates the OpenAI client with minimal config and no stop words
- The OpenAI-compatible endpoint accepts `stop` in request bodies, but Paperless-GPT doesn't send it

## Verification

The fix was verified with:

```bash
# 1. Confirmed llama-server supports the flags
nix shell nixpkgs#llama-cpp --command llama-server --help | grep -E 'repeat-penalty|repeat-last-n'

# 2. Verified the generated config includes the new flags
nixos-rebuild dry-run --flake .#nas
# Output showed: repeat-penalty 1.1 --repeat-last-n 256 in the generated config.yaml

# 3. Dry-run build succeeded (6 derivations will be built)
```

## Defense Layers

1. **Repeat penalty** (NEW): Server-side logit penalty discourages token repetition
2. **Deterministic decoding**: `--top-k 1 --temp 0` keeps output predictable
3. **Token limit**: `VISION_LLM_MAX_TOKENS=2048` caps maximum output length
4. **Context window**: 8192 tokens limits input+output scope

The repeat penalty is the strongest config-only defense available given that Paperless-GPT cannot be configured to send stop sequences.

# OpenCode Go model catalog — SINGLE SOURCE OF TRUTH.
#
# Every entry is a live model returned by https://opencode.ai/zen/go/v1/models
# (verified 2026-09-04). `provider` + `mode` are the LiteLLM adapter and protocol
# for that model, taken from the official OpenCode Go Endpoints table
# (https://opencode.ai/docs/go/, fetched 2026-09-04) unless an entry carries its
# own evidence note. The protocol a model is served on determines both:
#
#   /v1/responses        -> provider "openai",    mode "responses"
#   /v1/chat/completions -> provider "openai",    mode "chat"
#   /v1/messages         -> provider "anthropic", mode "chat"
#
# LiteLLM uses https://opencode.ai/zen/go/v1 for OpenAI routes and
# https://opencode.ai/zen/go for Anthropic routes; the provider determines the
# required base in default.nix. Auth (os.environ/OPENCODE_GO_API_KEY) is shared
# by all Go models and is intentionally not stored per-entry here.
#
# Go models are mixed-protocol, so this is one EXPLICIT route per id — never a
# wildcard. Both derivations consume this file and must not duplicate it:
#   * modules/nas/litellm/default.nix  -> LiteLLM `model_list` entries
#   * modules/nas/litellm/models.nix   -> OpenCode visible model IDs
#
# ── Intentionally EXCLUDED (documented, not forgotten) ────────────────────────
# gpt-5.6-luna — a Go Responses model per the docs table, but it is already served
#   by an explicit ChatGPT provider route in default.nix. Adding a Go route would
#   create a duplicate LiteLLM model_name; the ChatGPT entries own the gpt-5.6-*
#   family. It remains in the OpenCode catalog (models.nix) as a ChatGPT-backed
#   visible id.
#
{
  # ── Responses / OpenAI (mode "responses") ─────────────────────────────────────
  "muse-spark-1.3-contributor" = {
    provider = "openai";
    mode = "responses";
  };
  "muse-spark-1.2-contributor" = {
    provider = "openai";
    mode = "responses";
  };

  # ── Chat / OpenAI (mode "chat") ──────────────────────────────────────────────
  "glm-5.3-flash" = {
    provider = "openai";
    mode = "chat";
  };
  "deepseek-v4-flash" = {
    provider = "openai";
    mode = "chat";
  };
  "hy3" = {
    provider = "openai";
    mode = "chat";
  };
  "omen-alpha" = {
    provider = "openai";
    mode = "chat";
  };

  # ── Messages / Anthropic (mode "chat") ───────────────────────────────────────
  "qwen3.8-flash" = {
    provider = "anthropic";
    mode = "chat";
  };
  "qwen3.7-plus" = {
    provider = "anthropic";
    mode = "chat";
  };
}

# OpenCode model catalog (static list consumed by users/cody/harness/opencode).
# Derived from the single Go source of truth (./go-catalog.nix) unioned with the
# ChatGPT-backed gpt-5.6-* IDs that LiteLLM serves via explicit chatgpt provider
# routes (NOT Go). The Go catalog owns every opencode-go/* route; the ChatGPT
# entries own the gpt-5.6-* family. No model id appears in both.
#
# API keys are client-managed by OpenCode, not declared here.
(builtins.attrNames (import ./go-catalog.nix))
++ [
  # ChatGPT-backed (served by explicit routes in modules/nas/litellm/default.nix,
  # not by OpenCode Go). Excluded from
  # go-catalog.nix so the two never register a duplicate LiteLLM model_name.
  "gpt-5.6-luna"
  "gpt-5.6-terra"
  "gpt-5.6-sol"
]

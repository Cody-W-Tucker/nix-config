# Shared LiteLLM model IDs.
# Served by the NAS proxy (modules/nas/litellm) and consumed by
# Cody's OpenCode client (users/cody/harness/opencode). API keys are
# client-managed by OpenCode, not declared here.
[
  "gpt-5.6-luna"
  "gpt-5.6-terra"
  "gpt-5.6-sol"
  # OpenCode Go provider model — routed by LiteLLM to the
  # opencode.ai/zen/go upstream (see modules/nas/litellm/default.nix).
  "hy3"
]

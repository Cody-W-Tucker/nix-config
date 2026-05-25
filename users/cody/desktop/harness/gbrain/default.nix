{ osConfig, ... }:

{
  services.gbrain = {
    enable = true;
    environmentFile = osConfig.sops.templates."gbrain-opencode-env".path;
    chatModel = "openrouter:deepseek-v4-flash";
    factsExtractionModel = "openrouter:deepseek-v4-flash";
    providerBaseUrls.openrouter = "https://opencode.ai/zen/go/v1";
    runtimeConfig = {
      "models.chat" = "openrouter:deepseek-v4-flash";
      "models.expansion" = "openrouter:deepseek-v4-flash";
      "models.dream.synthesize" = "openrouter:kimi-k2.6";
      "models.dream.synthesize_verdict" = "openrouter:deepseek-v4-flash";
      "models.dream.patterns" = "openrouter:kimi-k2.6";
      "models.eval.longmemeval" = "openrouter:kimi-k2.6";
      "models.eval.contradictions_judge" = "openrouter:deepseek-v4-flash";
    };
  };
}

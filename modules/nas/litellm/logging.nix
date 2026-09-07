# Langfuse observability for the LiteLLM proxy, via LiteLLM's OpenTelemetry
# v2 pipeline (`langfuse_otel` + LITELLM_OTEL_V2). This is the ingestion path
# current Langfuse v4 accepts: the legacy `langfuse` callback posts to an
# event API that Langfuse v4 rejects.
#
# Owns the logging runtime end to end:
#   - pythonEnv: OpenTelemetry packages langfuse_otel imports at runtime,
#     exported as PYTHONPATH by default.nix,
#   - environment: non-secret env vars read by LiteLLM/langfuse_otel,
#     merged into services.litellm.environment,
#   - litellmSettings: the litellm_settings callback wiring.
# Langfuse credentials stay out of this file: they ride litellm-env via
# services.litellm.environmentFile in default.nix.
#
# services.litellm ships only on nixpkgs-unstable, so the OTel runtime is built
# from the same unstable python3 litellm is built against (litellmPkg has no
# .python attr).
{ inputs, pkgs }:

let
  openTelemetryPython =
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.python3.withPackages
      (
        pythonPackages: with pythonPackages; [
          opentelemetry-api
          opentelemetry-sdk
          opentelemetry-exporter-otlp-proto-http
        ]
      );
in
{
  # PYTHONPATH carrier for the langfuse_otel callback runtime.
  pythonEnv = openTelemetryPython;

  # Non-secret logging environment (merged into services.litellm.environment).
  environment = {
    # Selects the OTel v2 span/event pipeline over the legacy Langfuse event API.
    LITELLM_OTEL_V2 = "true";
    # Self-hosted Langfuse OTLP endpoint. This is the host var the v2 pipeline
    # reads; LANGFUSE_HOST is deliberately not set (it would be a duplicate —
    # the OTEL host takes precedence anyway).
    LANGFUSE_OTEL_HOST = "http://127.0.0.1:3000";
    # Tags exported traces as production (carried over from the legacy setup).
    LANGFUSE_TRACING_ENVIRONMENT = "production";
    # Capture request/response content on spans and generation events alike.
    OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = "span_and_event";
  };

  # Merged into litellm_settings. `callbacks` is the official single-list form:
  # LiteLLM routes both success and failure events to langfuse_otel.
  litellmSettings = {
    callbacks = [ "langfuse_otel" ];
  };
}

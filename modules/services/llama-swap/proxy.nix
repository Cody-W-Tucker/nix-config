# Proxy and wrapper configuration for llama-swap audio services.
# Defines Python environments, persistent paths, and wrapper commands
# that are reusable across hosts.

{ pkgs }:

let
  # Persistent paths for wrapper services
  sharedFasterWhisperCache = "/var/cache/llama-swap/faster-whisper";
  diarizationEnrollmentDir = "/var/lib/llama-swap/diarization/enrollment";
  diarizationEmbeddingCache = "/var/lib/llama-swap/diarization/embedding-cache";
  diarizationCache = "/var/cache/llama-swap/whisperx";

  kokoroAssets = pkgs.kokoro-assets;

  # Build Python environments with optional ctranslate2 override for specific CUDA architectures.
  # The ctranslate2 package uses its own CMake CUDA_ARCH_LIST and does not inherit nixpkgs cudaCapabilities.
  mkWhisperPython =
    ctranslate2Cpp:
    let
      whisperScope = pkgs.python313.override {
        packageOverrides = final: prev: {
          ctranslate2 = prev.ctranslate2.override {
            ctranslate2-cpp = ctranslate2Cpp;
          };
        };
      };
    in
    whisperScope.withPackages (
      ps: with ps; [
        fastapi
        faster-whisper
        python-multipart
        uvicorn
      ]
    );

  # Kokoro needs CUDA torch for GPU inference; the host-wide
  # nixpkgs.config.cudaSupport already provides it.
  mkKokoroPython =
    pkgs:
    pkgs.python313.withPackages (
      ps: with ps; [
        # Provide the spacy model that misaki's G2P (used by kokoro) requires.
        # Without it in the same env, misaki calls spacy.cli.download which fails
        # in the Nix python env (no pip/uv).
        spacy-models.en_core_web_sm
        fastapi
        kokoro
        numpy
        torch
        uvicorn
      ]
    );

  # WhisperX diarization server: speech-to-text with speaker labels.
  # Uses WhisperX for transcription + alignment and pyannote for diarization.
  # Both require CUDA for acceptable latency.
  # CUDA torch comes from the host-wide nixpkgs.config.cudaSupport.
  mkWhisperDiarizePython =
    pkgs:
    pkgs.python313.withPackages (
      ps: with ps; [
        fastapi
        python-multipart
        ps.torch
        uvicorn
        whisperx
      ]
    );

  # Default ctranslate2 without architecture-specific overrides
  defaultCTranslate2Cpp = pkgs.ctranslate2.override {
    withCUDA = true;
    withCuDNN = true;
  };
in
{
  inherit
    sharedFasterWhisperCache
    diarizationEnrollmentDir
    diarizationEmbeddingCache
    diarizationCache
    kokoroAssets
    mkWhisperPython
    mkKokoroPython
    mkWhisperDiarizePython
    defaultCTranslate2Cpp
    ;
}

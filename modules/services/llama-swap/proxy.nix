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

  kokoroAssets = (pkgs.callPackage ../../../packages/kokoro { }).assets;

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

  # Kokoro (and future torch-based audio models) need a CUDA-enabled torch
  # for GPU inference. The base python313Packages.torch is CPU-only.
  mkKokoroPython =
    pkgs:
    let
      torchWithCuda = pkgs.python313Packages.torch.override {
        cudaSupport = true;
      };
    in
    pkgs.python313.withPackages (
      ps: with ps; [
        # Provide the spacy model that misaki's G2P (used by kokoro) requires.
        # Without it in the same env, misaki calls spacy.cli.download which fails
        # in the Nix python env (no pip/uv).
        (pkgs.callPackage ../../../packages/kokoro { pythonPkgs = ps; }).en-core-web-sm
        fastapi
        kokoro
        numpy
        torchWithCuda
        uvicorn
      ]
    );

  # WhisperX diarization server: speech-to-text with speaker labels.
  # Uses WhisperX for transcription + alignment and pyannote for diarization.
  # Both require CUDA for acceptable latency.
  #
  # Override the entire Python 3.13 package set so torch carries CUDA by default.
  # This avoids the collision where stock whisperx propagates CPU torch while an
  # explicit CUDA torch is also present in withPackages.
  mkWhisperDiarizePython =
    pkgs:
    let
      whisperDiarizeScope = pkgs.python313.override {
        packageOverrides = final: prev: {
          torch = prev.torch.override { cudaSupport = true; };
        };
      };
    in
    whisperDiarizeScope.withPackages (
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

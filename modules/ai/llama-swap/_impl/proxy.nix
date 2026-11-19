# Proxy and wrapper configuration for llama-swap audio services.
# Defines Python environments, persistent paths, and wrapper commands
# that are reusable across hosts.

{ pkgs }:

let
  diarizationEnrollmentDir = "/var/lib/llama-swap/diarization/enrollment";
  diarizationEmbeddingCache = "/var/lib/llama-swap/diarization/embedding-cache";
  diarizationCache = "/var/cache/llama-swap/whisperx";

  kokoroAssets = pkgs.kokoro-assets;

  # sherpa-onnx speech recognition. Its onnxruntime gets the CUDA provider from
  # the host-wide nixpkgs.config.cudaSupport; ffmpeg decodes uploaded audio.
  mkSherpaPython =
    pkgs:
    pkgs.python313.withPackages (
      ps: with ps; [
        fastapi
        numpy
        python-multipart
        sherpa-onnx
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
in
{
  inherit
    diarizationEnrollmentDir
    diarizationEmbeddingCache
    diarizationCache
    kokoroAssets
    mkSherpaPython
    mkKokoroPython
    mkWhisperDiarizePython
    ;
}

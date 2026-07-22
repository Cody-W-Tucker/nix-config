# Speech-to-Text and Text-to-Speech Services

This page details the Speech-to-Text (STT) and Text-to-Speech (TTS) infrastructure within CodyOS. The system provides a unified pipeline for voice interaction, ranging from low-latency desktop dictation to a complex, VAD-enabled voice assistant integrated into the Waybar status bar. These services leverage local inference via `llama-swap` to provide OpenAI-compatible APIs for transcription and speech synthesis.

For navigation: Cody's Home Manager desktop role is entered through `users/cody/desktop.nix`, which imports `users/cody/desktop/`; the speech-specific implementation lives under that desktop directory [users/cody/desktop.nix9-13](../users/cody/desktop.nix#L9-L13)

## Architecture Overview

The speech pipeline is built on three primary server-side components and two client-side scripts. All servers are designed to be managed by `llama-swap`, which handles model lifecycle and hardware acceleration (CUDA/CPU) [modules/services/llama-swap/faster-whisper-openai-server.py37-60](../modules/services/llama-swap/faster-whisper-openai-server.py#L37-L60)

### Speech Service Components

| Component                | Implementation     | Role                          | API Endpoint               |
| ------------------------ | ------------------ | ----------------------------- | -------------------------- |
| **Transcription Server** | `faster-whisper`   | STT using Whisper models      | `/v1/audio/transcriptions` |
| **Diarization Server**   | `whisperx`         | Speaker-aware STT             | `/v1/audio/transcriptions` |
| **Kokoro TTS**           | `kokoro-82m`       | High-quality, fast TTS        | `/v1/audio/speech`         |
| **llama-dictate**        | Shell Script       | Hold-to-talk global dictation | N/A (Client)               |
| **hermes-waybar-voice**  | Python Script      | VAD-based voice assistant     | N/A (Client)               |

## Transcription Services

### Faster-Whisper Server

The primary transcription backend is an OpenAI-compatible FastAPI server wrapping `faster-whisper`[modules/services/llama-swap/faster-whisper-openai-server.py34-69](../modules/services/llama-swap/faster-whisper-openai-server.py#L34-L69)

- **Hardware Acceleration**: It attempts to initialize on `cuda` and falls back to `cpu` if CUDA initialization fails [modules/services/llama-swap/faster-whisper-openai-server.py40-60](../modules/services/llama-swap/faster-whisper-openai-server.py#L40-L60)
- **VAD Filtering**: Supports an optional VAD filter to remove silence from audio before transcription [modules/services/llama-swap/faster-whisper-openai-server.py30-31](../modules/services/llama-swap/faster-whisper-openai-server.py#L30-L31)
- **Endpoints**: Implements `/v1/audio/transcriptions` for standard file-based uploads [modules/services/llama-swap/faster-whisper-openai-server.py98-100](../modules/services/llama-swap/faster-whisper-openai-server.py#L98-L100)

### WhisperX Diarization Server

The diarization server provides speaker-aware transcription using WhisperX 3.8.6 for ASR + alignment and pyannote-audio 4.0.7 for speaker diarization. It is exposed as a separate `whisper-diarization` model in llama-swap.

- **GPU Phase Loading**: Loads ASR model, transcribes, unloads ASR, loads alignment model, aligns, unloads alignment, loads diarization pipeline, diarizes. Only one model is resident on GPU at a time.
- **Concurrency**: One-job limit enforced via threading lock. Returns **503 Service Unavailable** if another job is running.
- **CUDA Guard**: Refuses to start if CUDA is requested but unavailable. No silent CPU fallback.
- **Diarization Model**: Defaults to `pyannote/speaker-diarization-community-1` (no HF token required). Override with `--diarization-model` for gated models.
- **Enrollment API**: The `/v1/identity/enroll`, `/v1/identity/samples`, and `/v1/identity/candidates` endpoints exist but enrollment is **disabled (501)** until a verified embedding matcher is implemented. No raw audio is retained on disk.

#### Operator Prerequisites

1. **CUDA-capable GPU** — the server will refuse to start without one.
2. **HuggingFace token** — only required if using a gated diarization model (the default community model does not need one). Provide via `HF_TOKEN` environment variable or `--hf-token-path` flag.
3. **SOPS secret** — if using a gated model, create the secret at the path expected by your NixOS configuration. The exact secret name and path is operator-specific and must be wired into `serviceEnvironment` or `--hf-token-path`.

#### API Usage

**Basic diarization request:**

```bash
curl -s http://localhost:8081/v1/audio/transcriptions \
  -F file=@meeting.wav \
  -F model=whisper-diarization \
  -F response_format=diarized_json | jq .
```

**With speaker count hints:**

```bash
curl -s http://localhost:8081/v1/audio/transcriptions \
  -F file=@interview.wav \
  -F model=whisper-diarization \
  -F response_format=diarized_json \
  -F min_speakers=2 \
  -F max_speakers=5 | jq .
```

**Exact speaker count:**

```bash
curl -s http://localhost:8081/v1/audio/transcriptions \
  -F file=@duet.wav \
  -F model=whisper-diarization \
  -F response_format=diarized_json \
  -F num_speakers=2 | jq .
```

#### Response Format

```json
{
  "text": "Hello, how are you? I'm doing well, thanks.",
  "language": "en",
  "duration": 4.32,
  "segments": [
    {"start": 0.0, "end": 1.8, "text": "Hello, how are you?", "speaker": "SPEAKER_00"},
    {"start": 2.1, "end": 4.3, "text": "I'm doing well, thanks.", "speaker": "SPEAKER_01"}
  ],
  "speakers": ["SPEAKER_00", "SPEAKER_01"],
  "identity": {"mode": "off", "status": "not_requested"},
  "warnings": []
}
```

#### Speaker Enrollment

Enrollment endpoints are **disabled** (HTTP 501) until a cross-session embedding matcher is verified. No raw audio is accepted or stored on disk. The endpoints are preserved as API contracts for future enablement.

```bash
# These return 501 until embedding matching is verified:
curl -s -X POST http://localhost:8081/v1/identity/enroll \
  -F consent=true \
  -F person_id=cody \
  -F display_name="Cody" | jq .

curl -s http://localhost:8081/v1/identity/candidates | jq .
# Returns: {"status": "matching_unavailable", ...}
```

#### Data Retention

- **Transcription temp files**: Written to `/tmp` during processing, deleted in `finally` block after each request. No persistence.
- **Enrollment audio**: Not accepted — enrollment endpoints return 501.
- **Diarization model cache**: Stored under `/var/cache/llama-swap/whisperx` (persistent across restarts).
- **No raw audio retention by default**.

#### Verification Commands

```bash
# Check server health
curl -s http://localhost:8081/v1/health | jq .

# Verify model is registered
curl -s http://localhost:8081/v1/models | jq .

# Test busy response (send concurrent requests)
# First request should process, second should return 503

# Run smoke test with a short audio file
curl -s http://localhost:8081/v1/audio/transcriptions \
  -F file=@/path/to/test.wav \
  -F model=whisper-diarization \
  -F response_format=diarized_json | jq '.speakers | length'
```
```

### llama-dictate

`llama-dictate` is a desktop utility that provides global "hold-to-talk" functionality. It is bound to `SUPER+Escape` in Hyprland [users/cody/desktop/hyprland/settings.nix82-86](../users/cody/desktop/hyprland/settings.nix#L82-L86)

- **Mechanism**: On `start`, it triggers a "warmup" request to ensure the model is loaded in `llama-swap` and begins recording via `pw-record`[users/cody/desktop/speech-to-text.nix201-211](../users/cody/desktop/speech-to-text.nix#L201-L211) On `stop`, it kills the recorder, sends the WAV file to the local API, and pipes the resulting text into `wtype` to simulate keyboard input [users/cody/desktop/speech-to-text.nix168-196](../users/cody/desktop/speech-to-text.nix#L168-L196)

## Text-to-Speech Services

### Kokoro TTS Server

The system uses Kokoro-82M for high-performance speech synthesis. The server includes a `_install_local_voice_provider` function that patches `huggingface_hub` to serve model weights and voice assets from the Nix store (`pkgs.kokoro`) instead of downloading them at runtime [modules/services/llama-swap/kokoro-openai-server.py38-105](../modules/services/llama-swap/kokoro-openai-server.py#L38-L105)

- **Voice Mapping**: Maps standard OpenAI voice names (e.g., `alloy`, `nova`) to Kokoro-specific assets like `af_heart`[modules/services/llama-swap/kokoro-openai-server.py17-26](../modules/services/llama-swap/kokoro-openai-server.py#L17-L26)
- **Offline Mode**: When `voices-dir` and `model-path` are provided via Nix, the server operates in a fully offline mode [modules/services/llama-swap/kokoro-openai-server.py167-182](../modules/services/llama-swap/kokoro-openai-server.py#L167-L182)

## Hermes Voice Assistant

The `hermes-waybar-voice` system provides a sophisticated voice interface directly in the Waybar status bar. It features Voice Activity Detection (VAD) and a streaming LLM response pipeline.

### Implementation Details

The core logic resides in `hermes-waybar-voice.py`. It uses `pysilero-vad` for local, low-latency voice detection [users/cody/desktop/hermes-waybar-voice.py19-37](../users/cody/desktop/hermes-waybar-voice.py#L19-L37)

### Key Functions

- `ensure_runtime()`: Manages the XDG runtime directory for PID, lock, and session files [users/cody/desktop/hermes-waybar-voice.py64-66](../users/cody/desktop/hermes-waybar-voice.py#L64-L66)
- `waybar_status()`: Generates the JSON output for Waybar, including icons for different states (`` for listening, `` for speaking) [users/cody/desktop/hermes-waybar-voice.py155-188](../users/cody/desktop/hermes-waybar-voice.py#L155-L188)
- `stop_worker()`: Safely terminates the background voice worker and cleans up temporary session files [users/cody/desktop/hermes-waybar-voice.py190-210](../users/cody/desktop/hermes-waybar-voice.py#L190-L210)

### Configuration

The service is configured via environment variables in the `hermes-waybar-voice` wrapper:

- `HERMES_SPEECH_BASE_URL`: Points to the `llama-swap` STT/TTS port (default `8081`) [users/cody/desktop/waybar.nix21](../users/cody/desktop/waybar.nix#L21-L21)
- `HERMES_TRANSCRIPTION_MODEL`: Defaults to `whisper-medium`[users/cody/desktop/waybar.nix23](../users/cody/desktop/waybar.nix#L23-L23)
- `HERMES_SPEECH_VOICE`: Defaults to `af_heart` (Kokoro) [users/cody/desktop/waybar.nix25](../users/cody/desktop/waybar.nix#L25-L25)

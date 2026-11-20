# Speech-to-Text and Text-to-Speech Services

This page details the Speech-to-Text (STT) and Text-to-Speech (TTS) infrastructure within CodyOS. The system provides a unified pipeline for voice interaction, ranging from low-latency desktop dictation to a complex, VAD-enabled voice assistant integrated into the Waybar status bar. These services leverage local inference via `llama-swap` to provide OpenAI-compatible APIs for transcription and speech synthesis.

For navigation: the desktop speech pieces are the `speech-to-text` aspect ([modules/ai/speech-to-text.nix](../modules/ai/speech-to-text.nix), script in [`_speech-to-text.nix`](../modules/ai/_speech-to-text.nix)) and the Waybar voice client under [`modules/graphical/_waybar/`](../modules/graphical/_waybar)

## Public Audio API

The public audio API is `llama-swap` at `http://nas:8081`:

- `POST /v1/audio/transcriptions` with `model=fluid-speech-pro-clean` (general STT) or `model=whisper-diarization` (speaker-aware STT)
- `POST /v1/audio/speech` with `model=kokoro-82m`
- `GET /v1/audio/voices` with optional `model=kokoro-82m`

Wrapper upstream ports are dynamically assigned by `llama-swap` (`${PORT}` template substitution) and are not a client contract.

## Architecture Overview

The speech pipeline is built on three primary server-side components and two client-side scripts. All servers are managed by `llama-swap`, which handles model lifecycle and hardware acceleration [modules/ai/llama-swap/default.nix](../modules/ai/llama-swap/default.nix)

### Speech Service Components

| Component                | Implementation     | Role                          | API Endpoint               |
| ------------------------ | ------------------ | ----------------------------- | -------------------------- |
| **Transcription Server** | `sherpa-onnx`      | STT using Fluid Speech Pro in clean mode | `/v1/audio/transcriptions` |
| **Diarization Server**   | `whisperx`         | Speaker-aware STT             | `/v1/audio/transcriptions` |
| **Kokoro TTS**           | `kokoro-82m`       | High-quality, fast TTS        | `/v1/audio/speech`         |
| **llama-dictate**        | Shell Script       | Hold-to-talk global dictation | N/A (Client)               |
| **hermes-waybar-voice**  | Python Script      | VAD-based voice assistant     | N/A (Client)               |

## Transcription Services

### Fluid Speech Pro (sherpa-onnx) Server

The primary transcription backend, `fluid-speech-pro-clean`, is an OpenAI-compatible FastAPI server ([modules/ai/llama-swap/_impl/sherpa-onnx-openai-server.py](../modules/ai/llama-swap/_impl/sherpa-onnx-openai-server.py)) around the Nixpkgs `sherpa-onnx` Python bindings. It serves [Fluid Speech Pro by FluidVoice](https://huggingface.co/FluidVoice-Labs/fluid-speech-pro-onnx) (CC BY 4.0) with INT8 clean-mode graphs. Clean mode removes fillers and some repeated words, so this is not a verbatim transcript. `modules/ai/llama-swap/_nas-models.nix` pins the graphs and external weight files and passes them in through `services.llama-swap.fluidSpeechModel`.

- **Provider**: CUDA, with 4 CPU threads for supporting work. The CUDA provider was tested on the NAS's RTX 5060; actual memory use alongside the other audio models should be monitored.
- **Audio input**: Every upload is decoded with ffmpeg to 16 kHz mono, so WAV, Ogg/Opus, MP3, and M4A all work. Audio longer than 30 s is split at the quietest 100 ms frame near each boundary.
- **Readiness**: The model loads and runs one silent decode before `/health` answers. That means `GET /upstream/fluid-speech-pro-clean/health` returns only once the backend is warm.
- **API surface**: `response_format` may be `json` (default), `text`, or `verbose_json` (`segments` is empty). `language` does not force recognition in a particular language; Fluid detects its 25 European languages itself. `prompt` and `temperature` are ignored. `task=translate` returns 422.

There is no STT fallback model. `llama-dictate` and `hermes-waybar-voice` send audio to `fluid-speech-pro-clean`; an empty result means no speech was decoded.

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
curl -s http://nas:8081/v1/audio/transcriptions \
  -F file=@meeting.wav \
  -F model=whisper-diarization \
  -F response_format=diarized_json | jq .
```

**With speaker count hints:**

```bash
curl -s http://nas:8081/v1/audio/transcriptions \
  -F file=@interview.wav \
  -F model=whisper-diarization \
  -F response_format=diarized_json \
  -F min_speakers=2 \
  -F max_speakers=5 | jq .
```

**Exact speaker count:**

```bash
curl -s http://nas:8081/v1/audio/transcriptions \
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
curl -s -X POST http://nas:8081/v1/identity/enroll \
  -F consent=true \
  -F person_id=cody \
  -F display_name="Cody" | jq .

curl -s http://nas:8081/v1/identity/candidates | jq .
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
curl -s http://nas:8081/v1/health | jq .

# Verify model is registered
curl -s http://nas:8081/v1/models | jq .

# Test busy response (send concurrent requests)
# First request should process, second should return 503

# Run smoke test with a short audio file
curl -s http://nas:8081/v1/audio/transcriptions \
  -F file=@/path/to/test.wav \
  -F model=whisper-diarization \
  -F response_format=diarized_json | jq '.speakers | length'
```
```

### llama-dictate

`llama-dictate` is a desktop utility that provides global "hold-to-talk" functionality. It is bound to `SUPER+Escape` in Hyprland [modules/graphical/_hyprland/settings.nix](../modules/graphical/_hyprland/settings.nix)

- **Mechanism**: On `start`, it triggers a "warmup" request to ensure the model is loaded in `llama-swap` and begins recording via `pw-record`[modules/ai/_speech-to-text.nix](../modules/ai/_speech-to-text.nix) On `stop`, it kills the recorder, sends the WAV file to the local API, and pipes the resulting text into `wtype` to simulate keyboard input [modules/ai/_speech-to-text.nix](../modules/ai/_speech-to-text.nix)

## Text-to-Speech Services

### Kokoro TTS Server

The system uses Kokoro-82M for high-performance speech synthesis. The server includes a `_install_local_voice_provider` function that patches `huggingface_hub` to serve model weights and voice assets from the Nix store (`pkgs.kokoro`) instead of downloading them at runtime [modules/ai/llama-swap/kokoro-openai-server.py](../modules/ai/llama-swap/kokoro-openai-server.py)

- **Voice Mapping**: Maps standard OpenAI voice names (e.g., `alloy`, `nova`) to Kokoro-specific assets like `af_heart`[modules/ai/llama-swap/kokoro-openai-server.py](../modules/ai/llama-swap/kokoro-openai-server.py)
- **Offline Mode**: When `voices-dir` and `model-path` are provided via Nix, the server operates in a fully offline mode [modules/ai/llama-swap/kokoro-openai-server.py](../modules/ai/llama-swap/kokoro-openai-server.py)

## Hermes Voice Assistant

The `hermes-waybar-voice` system provides a sophisticated voice interface directly in the Waybar status bar. It features Voice Activity Detection (VAD) and a streaming LLM response pipeline.

### Implementation Details

The graphical aspect includes the Hermes voice client; Waybar owns the button, while Hermes owns the [client script](../modules/ai/hermes-agent/_voice/hermes-waybar-voice.py). It uses `pysilero-vad` for local, low-latency voice detection. The microphone is read with `pw-record --raw` so the VAD receives header-less 16 kHz little-endian s16 PCM; without `--raw`, `pw-record` writes a Sun AU stream (big-endian) to stdout, which the VAD cannot recognize as speech.

### Key Functions

- `ensure_runtime()`: Manages the XDG runtime directory for PID, lock, and session files.
- `waybar_status()`: Generates the JSON output for Waybar, including icons for different states (`` for listening, `` for speaking).
- `stop_worker()`: Terminates the background voice worker and cleans up temporary session files.

### Configuration

The service is configured via environment variables in the `hermes-waybar-voice` wrapper:

- `HERMES_SPEECH_BASE_URL`: Points to the `llama-swap` STT/TTS port (default `8081`) [modules/graphical/_waybar/waybar.nix](../modules/graphical/_waybar/waybar.nix)
- `HERMES_TRANSCRIPTION_MODEL`: Set to `fluid-speech-pro-clean` by [the voice client](../modules/ai/hermes-agent/_voice/client.nix)
- `HERMES_SPEECH_VOICE`: Defaults to `af_heart` (Kokoro) [modules/graphical/_waybar/waybar.nix](../modules/graphical/_waybar/waybar.nix)

# Speech-to-Text and Text-to-Speech Services

This page details the Speech-to-Text (STT) and Text-to-Speech (TTS) infrastructure within CodyOS. The system provides a unified pipeline for voice interaction, ranging from low-latency desktop dictation to a complex, VAD-enabled voice assistant integrated into the Waybar status bar. These services leverage local inference via `llama-swap` to provide OpenAI-compatible APIs for transcription and speech synthesis.

## Architecture Overview

The speech pipeline is built on three primary server-side components and two client-side scripts. All servers are designed to be managed by `llama-swap`, which handles model lifecycle and hardware acceleration (CUDA/CPU) [modules/services/llama-swap/faster-whisper-openai-server.py37-60](../modules/services/llama-swap/faster-whisper-openai-server.py#L37-L60)

### Speech Service Components

| Component                | Implementation   | Role                          | API Endpoint               |
| ------------------------ | ---------------- | ----------------------------- | -------------------------- |
| **Transcription Server** | `faster-whisper` | STT using Whisper models      | `/v1/audio/transcriptions` |
| **Kokoro TTS**           | `kokoro-82m`     | High-quality, fast TTS        | `/v1/audio/speech`         |
| **Transformers TTS**     | `speecht5_tts`   | Fallback/Alternative TTS      | `/v1/audio/speech`         |
| **llama-dictate**        | Shell Script     | Hold-to-talk global dictation | N/A (Client)               |
| **hermes-waybar-voice**  | Python Script    | VAD-based voice assistant     | N/A (Client)               |

## Transcription Services

### Faster-Whisper Server

The primary transcription backend is an OpenAI-compatible FastAPI server wrapping `faster-whisper`[modules/services/llama-swap/faster-whisper-openai-server.py34-69](../modules/services/llama-swap/faster-whisper-openai-server.py#L34-L69)

- **Hardware Acceleration**: It attempts to initialize on `cuda` and falls back to `cpu` if CUDA initialization fails [modules/services/llama-swap/faster-whisper-openai-server.py40-60](../modules/services/llama-swap/faster-whisper-openai-server.py#L40-L60)
- **VAD Filtering**: Supports an optional VAD filter to remove silence from audio before transcription [modules/services/llama-swap/faster-whisper-openai-server.py30-31](../modules/services/llama-swap/faster-whisper-openai-server.py#L30-L31)
- **Endpoints**: Implements `/v1/audio/transcriptions` for standard file-based uploads [modules/services/llama-swap/faster-whisper-openai-server.py98-100](../modules/services/llama-swap/faster-whisper-openai-server.py#L98-L100)

### llama-dictate

`llama-dictate` is a desktop utility that provides global "hold-to-talk" functionality. It is bound to `SUPER+Escape` in Hyprland [users/cody/desktop/hyprland/settings.nix82-86](../users/cody/desktop/hyprland/settings.nix#L82-L86)

- **Mechanism**: On `start`, it triggers a "warmup" request to ensure the model is loaded in `llama-swap` and begins recording via `pw-record`[users/cody/desktop/speech-to-text.nix201-211](../users/cody/desktop/speech-to-text.nix#L201-L211) On `stop`, it kills the recorder, sends the WAV file to the local API, and pipes the resulting text into `wtype` to simulate keyboard input [users/cody/desktop/speech-to-text.nix168-196](../users/cody/desktop/speech-to-text.nix#L168-L196)

## Text-to-Speech Services

### Kokoro TTS Server

The system uses Kokoro-82M for high-performance speech synthesis. The server includes a `_install_local_voice_provider` function that patches `huggingface_hub` to serve model weights and voice assets from the Nix store (`pkgs.kokoro`) instead of downloading them at runtime [modules/services/llama-swap/kokoro-openai-server.py38-105](../modules/services/llama-swap/kokoro-openai-server.py#L38-L105)

- **Voice Mapping**: Maps standard OpenAI voice names (e.g., `alloy`, `nova`) to Kokoro-specific assets like `af_heart`[modules/services/llama-swap/kokoro-openai-server.py17-26](../modules/services/llama-swap/kokoro-openai-server.py#L17-L26)
- **Offline Mode**: When `voices-dir` and `model-path` are provided via Nix, the server operates in a fully offline mode [modules/services/llama-swap/kokoro-openai-server.py167-182](../modules/services/llama-swap/kokoro-openai-server.py#L167-L182)

### Transformers TTS Server

A secondary TTS server using Microsoft's `speecht5_tts` is available as a fallback. It utilizes the `Matthijs/cmu-arctic-xvectors` dataset for speaker embeddings [modules/services/llama-swap/transformers-tts-openai-server.py45-58](../modules/services/llama-swap/transformers-tts-openai-server.py#L45-L58)

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


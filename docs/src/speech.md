# Speech to text and text to speech

On beast: dictation into any window, and a spoken conversation with Hermes. The NAS does recognition and synthesis; any machine at home can use the same models over HTTP.

## Dictation

1. Press `SUPER + Escape` and speak.
2. Press `SUPER + Escape` again. The text is typed at the cursor, cleaned of fillers ("um", "uh") and some repeated words. Language is detected automatically (25 European languages).

A short sentence appears almost at once. The NAS's graphics card holds the speech models or a chat model, not both. After a large chat model has run (Open WebUI, Paperless-GPT OCR), the first dictation takes a few seconds longer while the speech models load again. If nothing is typed, no speech was recognized. `SUPER + Shift + Escape` resets a stuck dictation.

## Talking to Hermes

Click the voice button on Waybar and speak. When you stop, Hermes answers aloud in a sentence or two; it does not hear itself while it speaks. Left-click during a reply interrupts it. Right-click pauses and keeps the conversation. Middle-click starts a new one.

## Over HTTP

OpenAI-style endpoints on `http://nas:8081/v1`. Audio is deleted after transcription.

```bash
# Speech to text
curl -s http://nas:8081/v1/audio/transcriptions -F file=@note.m4a \
  -F model=fluid-speech-pro-clean | jq -r .text

# Text to speech (voice: af_heart, or an OpenAI name such as alloy, nova)
curl -s http://nas:8081/v1/audio/speech -H 'Content-Type: application/json' \
  -d '{"model": "kokoro-82m", "input": "Hello.", "voice": "af_heart"}' -o hello.mp3

# Meeting recording, split by speaker (optional: num_speakers, min_speakers, max_speakers)
curl -s http://nas:8081/v1/audio/transcriptions -F file=@meeting.wav \
  -F model=whisper-diarization -F response_format=diarized_json | jq .
```

`whisper-diarization` takes one recording at a time and answers a second request with `503`.

When building the speaker cache, the server logs a warning for each segment shorter than 0.3 seconds and skips it. The build still succeeds if it has at least one usable speaker label.

## Changing it

| To change | Edit |
| --- | --- |
| Dictation keys | [`_hyprland/settings.nix`](../../modules/graphical/_hyprland/settings.nix) |
| Dictation behavior | [`_speech-to-text.nix`](../../modules/ai/_speech-to-text.nix) |
| Voice button: model, voice, endpoint | [`_voice/client.nix`](../../modules/ai/hermes-agent/_voice/client.nix) |
| The speech models | [`_nas-models.nix`](../../modules/ai/llama-swap/_nas-models.nix) |

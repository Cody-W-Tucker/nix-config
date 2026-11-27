# Speech to text and text to speech

On beast: dictation into any window, and a spoken conversation with Hermes. The NAS does recognition and synthesis; any machine at home can use the same models over HTTP.

## Dictation

1. Press `SUPER + Escape` and speak.
2. Press `SUPER + Escape` again. The text is typed at the cursor, cleaned of fillers ("um", "uh") and some repeated words. Language is detected automatically (25 European languages).

Speech models load when you first dictate or play a reply. They leave the NAS's graphics card after 30 seconds without a request. The first request can take longer while they load or wait for another model. If nothing is typed, no speech was recognized. `SUPER + Shift + Escape` resets a stuck dictation.

### Teaching it words

When a word comes out wrong, press `SUPER + Ctrl + Escape`. The last dictation opens in a box; fix it and press Enter. A notification shows what was learned, and from the next transcription on the fix applies to everything recognized on the NAS, Hermes voice included.

Only short swaps teach anything ("Nix OS" → "NixOS"); a rewritten sentence teaches nothing. A swap between two ordinary words ("their" → "there") is never applied on its own, because it would be wrong elsewhere; it is only noted.

| Command | Shows or does |
| --- | --- |
| `llama-dictate vocabulary` | Every rule in effect, in the format of the vocabulary file |
| `llama-dictate suggestions` | Ordinary-word swaps noted but not applied |
| `llama-dictate forget "Nix OS"` | Stops applying a learned rule |

Learned rules live on the NAS. To make them part of the system, so a rebuilt NAS starts with them, run `llama-dictate vocabulary > modules/ai/llama-swap/_speech-vocabulary.json` in the repository and commit it. A rule in that file comes back after `forget`; remove it from the file instead.

## Talking to Hermes

Click the voice button on Waybar and speak. When you stop, Hermes answers aloud in a sentence or two; it does not hear itself while it speaks. Left-click during a reply interrupts it. Right-click pauses and keeps the conversation. Middle-click starts a new one.

## Over HTTP

OpenAI-style endpoints on `http://nas:8081/v1`. Every Fluid transcription, from any client, is kept on the NAS with its text and the vocabulary fixes applied to it; the audio is deleted after 30 days, the text is kept and backed up. If that history service is down, transcription still works, without the fixes.

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
| Declared vocabulary | [`_speech-vocabulary.json`](../../modules/ai/llama-swap/_speech-vocabulary.json) |
| How fixes are learned and applied | [`speech-history.py`](../../modules/ai/llama-swap/speech-history.py) |
| Voice button: model, voice, endpoint | [`_voice/client.nix`](../../modules/ai/hermes-agent/_voice/client.nix) |
| The speech models | [`_audio.nix`](../../modules/ai/llama-swap/_audio.nix) |

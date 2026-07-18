import { spawn } from "node:child_process"
import { access, mkdtemp, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"

import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"

interface VoiceConfig {
  apiUrl: string
  model: string
  voice: string
  responseFormat: string
  recordingPidPath: string
}

const defaultConfig: VoiceConfig = {
  apiUrl: "http://127.0.0.1:8081/v1/audio/speech",
  model: "kokoro-82m",
  voice: "af_heart",
  responseFormat: "wav",
  recordingPidPath: "/tmp/llama-dictate-recording.pid",
}

function loadConfig(): VoiceConfig {
  return {
    apiUrl: process.env.OPENCODE_VOICE_TTS_API_URL ?? defaultConfig.apiUrl,
    model: process.env.OPENCODE_VOICE_TTS_MODEL ?? defaultConfig.model,
    voice: process.env.OPENCODE_VOICE_TTS_VOICE ?? defaultConfig.voice,
    responseFormat: process.env.OPENCODE_VOICE_TTS_RESPONSE_FORMAT ?? defaultConfig.responseFormat,
    recordingPidPath: process.env.OPENCODE_VOICE_RECORDING_PID_PATH ?? defaultConfig.recordingPidPath,
  }
}

async function canSpeak(config: VoiceConfig): Promise<boolean> {
  try {
    await access(config.recordingPidPath)
    return false
  } catch {
    return true
  }
}

async function playAudio(buffer: Buffer): Promise<boolean> {
  const dir = await mkdtemp(join(tmpdir(), "opencode-voice-"))
  const file = join(dir, "speech.wav")

  try {
    await writeFile(file, buffer)

    return await new Promise<boolean>((resolve) => {
      const child = spawn("mpv", ["--no-terminal", "--really-quiet", file], {
        detached: true,
        stdio: "ignore",
      })

      child.once("error", () => {
        void rm(dir, { force: true, recursive: true })
        resolve(false)
      })

      child.once("spawn", () => {
        child.unref()
        resolve(true)
      })

      child.once("exit", () => {
        void rm(dir, { force: true, recursive: true })
      })
    })
  } catch {
    return false
  }
}

export const VoicePlugin: Plugin = async () => {
  const config = loadConfig()

  async function speak(text: string): Promise<boolean> {
    if (!(await canSpeak(config))) {
      return true
    }

    try {
      const response = await fetch(config.apiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          input: text,
          model: config.model,
          voice: config.voice,
          response_format: config.responseFormat,
        }),
      })

      if (!response.ok) {
        return false
      }

      const audio = Buffer.from(await response.arrayBuffer())
      return await playAudio(audio)
    } catch {
      return false
    }
  }

  return {
    tool: {
      speak: tool({
        description:
          "Speak a short response aloud through the local llama-swap TTS endpoint. " +
          "Use this sparingly for substantial completion notices, important blockers that need the user's attention, " +
          "or long-running background work finishing. Keep it to one short status line, not a full summary.",
        args: {
          text: tool.schema.string().describe("The text to speak aloud."),
        },
        async execute(args) {
          const success = await speak(args.text)
          return success ? `\"${args.text}\"` : `[TTS error] \"${args.text}\"`
        },
      }),
    },
  }
}

export default VoicePlugin

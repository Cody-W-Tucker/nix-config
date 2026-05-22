#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import tempfile
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Minimal OpenAI-compatible TTS wrapper for llama-tts")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--vocoder", required=True)
    parser.add_argument("--llama-tts", required=True)
    parser.add_argument("--model-id", required=True)
    return parser


class Handler(BaseHTTPRequestHandler):
    server_version = "llama-tts-openai/0.1"

    def _route_path(self):
        return urlparse(self.path).path

    def _write_json(self, status: int, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(length) or b"{}")

    def do_GET(self):
        route_path = self._route_path()

        if route_path in ("/health", "/v1/health"):
            self._write_json(HTTPStatus.OK, {"status": "ok"})
            return

        if route_path in ("/v1/models", "/models"):
            self._write_json(
                HTTPStatus.OK,
                {
                    "object": "list",
                    "data": [
                        {
                            "id": self.server.model_id,
                            "object": "model",
                            "owned_by": "local",
                        }
                    ],
                },
            )
            return

        if route_path in ("/v1/audio/voices", "/audio/voices"):
            self._write_json(
                HTTPStatus.OK,
                {
                    "object": "list",
                    "data": [],
                },
            )
            return

        self._write_json(HTTPStatus.NOT_FOUND, {"error": {"message": "Not found"}})

    def do_POST(self):
        route_path = self._route_path()

        if route_path not in ("/v1/audio/speech", "/audio/speech"):
            self._write_json(HTTPStatus.NOT_FOUND, {"error": {"message": "Not found"}})
            return

        try:
            payload = self._read_json()
        except json.JSONDecodeError:
            self._write_json(HTTPStatus.BAD_REQUEST, {"error": {"message": "Invalid JSON payload"}})
            return

        text = (payload.get("input") or "").strip()
        if not text:
            self._write_json(HTTPStatus.BAD_REQUEST, {"error": {"message": "Missing input text"}})
            return

        with tempfile.TemporaryDirectory(prefix="llama-tts-") as temp_dir:
            output_file = os.path.join(temp_dir, "speech.wav")
            cmd = [
                self.server.llama_tts,
                "-m",
                self.server.model_path,
                "-mv",
                self.server.vocoder_path,
                "--tts-use-guide-tokens",
                "-ngl",
                "999",
                "-p",
                text,
                "-o",
                output_file,
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                self._write_json(
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                    {
                        "error": {
                            "message": "llama-tts failed",
                            "details": result.stderr.strip() or result.stdout.strip(),
                        }
                    },
                )
                return

            with open(output_file, "rb") as f:
                audio = f.read()

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(audio)))
        self.end_headers()
        self.wfile.write(audio)


def main():
    args = build_parser().parse_args()

    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    httpd.model_path = args.model
    httpd.vocoder_path = args.vocoder
    httpd.llama_tts = args.llama_tts
    httpd.model_id = args.model_id
    httpd.serve_forever()


if __name__ == "__main__":
    main()

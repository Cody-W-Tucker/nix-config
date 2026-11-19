# Documents

`paperless` (server side, with `paperless.scanner`, beast's scanner client, in `paperless.nix`), `paperless-gpt` and `tika`; each is included directly by `modules/hosts/nas.nix` (the scanner by `modules/hosts/beast.nix`).

## Paperless and Tika

`paperless.nix` runs Paperless-ngx at `paperless.homehub.tv`. Apache Tika is provided by `tika.nix` and Paperless points to the local Tika endpoint for richer document extraction.

Paperless consume behavior is tuned for operator convenience:

- Recursive consume is enabled.
- Subdirectories become tags.
- Polling is frequent for quick ingest.
- Samba exposes a `PaperlessConsume` drop zone.


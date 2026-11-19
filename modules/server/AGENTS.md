# NAS services awaiting relocation

Holds `media/`, `paperless.nix`, `paperless-gpt.nix`, `tika.nix`, `open-webui.nix` and `langfuse/`, each a `den.aspects.<service>` included directly by `modules/hosts/nas.nix`. The rules for NAS services (backups registration, secrets, `config.codyos.site`, `mkNginxVhost`, option namespaces) are in [`modules/web/AGENTS.md`](../web/AGENTS.md); `README.md` documents these services.

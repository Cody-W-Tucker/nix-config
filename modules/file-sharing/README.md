# File sharing

Samba and NFS share files on the LAN. Syncthing replicates the shared folder between NAS and Beast; `syncthing.nginx` adds the Tailscale-only management routes on NAS.

## Samba

`modules/file-sharing/samba.nix` provides LAN-only file sharing and WSDD discovery. Shares are limited to the local subnet and localhost.

| Share | Path | Purpose |
| --- | --- | --- |
| `codytHome` | `/mnt/backup/Share` | General personal storage |
| `Music` | `/mnt/media/Music` | Music library management |
| `PaperlessConsume` | `/var/lib/paperless/consume` | Document OCR drop zone; [Paperless](../documents/paperless.nix) owns the export and Beast's scanner mount |

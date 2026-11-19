# File sharing

`samba.server`/`samba.client` and `nfs.server`/`nfs.client`: LAN file sharing between nas (server sides) and beast (client sides).

## Samba

`modules/file-sharing/samba.nix` provides LAN-only file sharing and WSDD discovery. Shares are limited to the local subnet and localhost.

| Share | Path | Purpose |
| --- | --- | --- |
| `codytHome` | `/mnt/media/Share` | General personal storage |
| `Music` | `/mnt/media/Music` | Music library management |
| `PaperlessConsume` | `/var/lib/paperless/consume` | Document OCR drop zone |


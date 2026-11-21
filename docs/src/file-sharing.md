# File sharing and sync

On beast, `~/Projects` and `~/Knowledge` are the NAS's directories, and the media folders in `$HOME` sync with the NAS. Other LAN devices reach the NAS over SMB as `smbnix`. NFS and SMB work on the LAN only, not over Tailscale.

## On beast

| Path | Is |
| --- | --- |
| `~/Projects`, `~/Knowledge` | The NAS's `/mnt/projects` and `/mnt/knowledge` over NFS. The first access after boot pauses briefly while the automount connects. |
| `~/Documents`, `~/Music`, `~/Pictures`, `~/Videos` | Folders in `Share`, synced with the NAS by Syncthing. `.git`, `node_modules`, `.venv`, `__pycache__`, `tmp` and similar folders are not synced, so a repository in `Share` arrives without history. |

## From other devices

| SMB share on `smbnix` | Contents | Sign-in |
| --- | --- | --- |
| `codytHome` | `Share`: Documents, Music, Pictures, Videos | `codyt` |
| `Music` | The media library's music (not beast's `~/Music`) | `codyt` |
| `PaperlessConsume` | Drop box for [Documents](documents.md) | Guest |

## Syncthing

UIs: [beast-syncthing.homehub.tv](https://beast-syncthing.homehub.tv), [nas-syncthing.homehub.tv](https://nas-syncthing.homehub.tv) (Tailscale only). Devices and folders are managed in Nix; anything added in the UI is removed at the next switch.

## Changing it

All in [`modules/file-sharing/`](../../modules/file-sharing):

| To change | Edit |
| --- | --- |
| NFS exports, beast mounts | [`nfs.nix`](../../modules/file-sharing/nfs.nix) |
| SMB shares (`PaperlessConsume`: [`paperless.nix`](../../modules/documents/paperless.nix)) | [`samba.nix`](../../modules/file-sharing/samba.nix) |
| Synced folders, ignores, devices | [`syncthing.nix`](../../modules/file-sharing/syncthing.nix) |

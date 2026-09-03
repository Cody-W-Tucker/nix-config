# LiteLLM Stateless Migration — Implementation Status

**Source plan:** `plans/litellm-stateless-migration.md`
**Status:** DB-free cutover implemented in Nix. The LiteLLM database has been **intentionally retired from Nix configuration**: no `ensureDatabases`/`ensureUsers`, no `postgresqlBackup`, and no `zfs-create-backup-litellm` / `postgresqlBackup-litellm` units remain. Postgres itself stays enabled only so the operator can still export the existing, now-unmanaged `litellm` DB. Secret-population, OpenCode session delivery, and the **manual** DB-data export/drop remain operator actions.

## What changed in Nix

The forked `litellm-nix` package/module is replaced by the upstream `services.litellm`
module from `nixpkgs-unstable` (pinned to 1.97.0 while the rest of the `nas` host stays
on stable `nixpkgs`). Authentication is master-key-only (no per-user virtual keys).
**LiteLLM now runs DB-free**: there is no `database_url` in `general_settings`, no
Postgres role/migration/combine units, and no LiteLLM systemd `requires`/`after` tied to
Postgres.

| File | Change |
| ---- | ------ |
| `modules/nas/litellm/default.nix` | Removed `inputs.litellm-nix` import and the `services.litellm-nix` block. Added `services.litellm` (upstream) with `package = inputs.nixpkgs-unstable.legacyPackages.${system}.litellm`, `host`/`port`/`stateDir`, `environment`, `environmentFile`, and `settings`. `environmentFile` is now the sole `litellm-env` SOPS secret directly. Removed the transitional `litellm-db-role` and `litellm-env-combine` units, the `litellm-database-env` and `litellm-master-key` secrets, and the `litellm-master-key-env` / `litellm-openai-api-key-env` SOPS templates. Added `litellm-openai-api-key-env.service` (a oneshot that derives `OPENAI_API_KEY` from `LITELLM_MASTER_KEY` inside `litellm-env` at activation) plus explicit `after`/`requires` on the gateway-client units and `restartUnits` on `litellm-env`. Removed `litellm-langfuse-env` + `opencode-go-api-key-env` (folded into `litellm-env`). |
| `modules/nas/litellm/default.nix` (DB-free) | `litellmSettings.general_settings` carries only `master_key = "os.environ/LITELLM_MASTER_KEY"` (no `database_url`). All LiteLLM-specific Postgres/database config and the backup/ZFS units have been removed from Nix — `services.postgresql` stays enabled only so the operator can export the existing `litellm` DB manually. |
| `modules/nas/karakeep.nix` | `OPENAI_BASE_URL` → `https://ai.homehub.tv/v1`; `services.karakeep.environmentFile` = `/run/litellm-openai-api-key/openai-api-key-env` (derived from litellm-env; literal `OPENAI_API_KEY = "blank"` removed). |
| `modules/nas/paperless-gpt.nix` | `OPENAI_BASE_URL` → `https://ai.homehub.tv/v1`; literal `OPENAI_API_KEY = "localonly"` removed; `/run/litellm-openai-api-key/openai-api-key-env` added to `environmentFiles`. |
| `modules/nas/content.nix` | Miniflux curator `openaiHost` → `https://ai.homehub.tv/v1`; added `openaiApiKeyEnvFile = /run/litellm-openai-api-key/openai-api-key-env`. |
| `modules/services/automations/miniflux-curator/default.nix` | Added `openaiApiKeyEnvFile` option (a systemd EnvironmentFile, not a bare key file); wired as `serviceConfig.EnvironmentFile`. |
| `modules/services/automations/miniflux-curator/script.nix` | Wrapper now validates `OPENAI_API_KEY`. |
| `users/cody/harness/opencode/default.nix` | `litellm` provider gains `options.apiKey = "{env:LITELLM_API_KEY}"` (no literal key). |

## LiteLLM database retired from Nix (manual export/drop boundary)

LiteLLM no longer connects to Postgres, and **all LiteLLM-specific Postgres configuration
has been removed from Nix**:

- `services.postgresql.ensureDatabases = [ "litellm" ]` and the `litellm` role are gone.
- `services.postgresqlBackup` (scoped to the `litellm` DB) is gone.
- The `backup/litellm` ZFS dataset, `zfs-create-backup-litellm`, and the
  `postgresqlBackup-litellm` binding units are gone.

**Applying this change will NOT drop the existing `litellm` database or its data
automatically.** `ensureDatabases`/`ensureUsers` removal only stops Nix from *managing*
the DB/role — the existing data remains in Postgres's data directory, and
`services.postgresql.enable = true` is kept so the operator can still reach it. The
`litellm` DB, its role, and the `backup/litellm` ZFS dataset persist on disk until the
operator removes them explicitly.

When the operator is ready, retire the data **manually and separately** from this Nix
change:

```bash
# 1. Export (optional but recommended) while Postgres is still serving the DB:
sudo -u postgres pg_dump litellm > litellm-export.sql

# 2. Drop the role/DB and the ZFS backup dataset when no longer needed:
sudo -u postgres psql -c 'DROP DATABASE IF EXISTS litellm;'
sudo -u postgres psql -c 'DROP ROLE IF EXISTS litellm;'
sudo zfs destroy -r backup/litellm
```

Only after both the data export/retention decision **and** the manual drop above should
`services.postgresql.enable` be reconsidered if Postgres is otherwise unused on this host.

## Manual blockers (must be done by the owner before / after switch)

1. **Fold SOPS values (`litellm-env`).** `litellm-env` must carry
   `LITELLM_MASTER_KEY`, `OPENCODE_GO_API_KEY`, `LANGFUSE_PUBLIC_KEY`,
   `LANGFUSE_SECRET_KEY` (and any salt/UI values). Move the values previously in
   `litellm-langfuse-env` and the `opencode-go-api-key-env` template into `litellm-env`
   via `sops edit`, then delete the two old secrets. Until done, hy3 / Langfuse tracing
   will lack creds.
2. **No separate `litellm-master-key` secret.** The gateway and all clients derive
   `OPENAI_API_KEY` from `LITELLM_MASTER_KEY` inside `litellm-env` (see
   `litellm-openai-api-key-env.service`). There is no `litellm-master-key` scalar secret
   and no `litellm-master-key-env` template anymore.
3. **Remove now-unused legacy secrets from the secrets repo.** Nix no longer references
   `litellm-database-env` or `litellm-master-key`, so they can be deleted from the
   external secrets repo. **Do this only after confirming Nix no longer references them**
   — this cutover removes every reference. `litellm-env` is the sole remaining LiteLLM
   credential secret. (This is an operator `sops` action in the separate secrets repo; do
   not commit raw secrets and do not touch the secrets repo from this Nix config.)
4. **OpenCode session delivery (plan §13 #5) — UNSELECTED.** How `LITELLM_API_KEY`
   reaches Cody's interactive OpenCode session from SOPS is an owner decision and is
   deliberately not implemented. The Nix prep (`{env:LITELLM_API_KEY}`) is in place; the
   delivery mechanism must be designed and validated.
5. **ChatGPT login option (plan §13 #2).** Verify against 1.97.0 whether
    `additional_drop_params = [ "previous_response_id" ]` is still required, and whether
    `requireChatgptAuth`/`enableChatgptLogin` map to an upstream `litellm_settings` /
    `general_settings` key. Kept as a conservative no-op for now. The service sets
    `CHATGPT_TOKEN_DIR=/var/lib/litellm/chatgpt` explicitly because LiteLLM otherwise
    tries to create `/.config` under its hardened DynamicUser sandbox; confirm the
    ChatGPT device-flow authenticator still writes `auth.json` after cutover.
6. **DB migration gate — RESOLVED by DB-free cutover.** Because LiteLLM no longer uses
   `database_url`, there is no 1.89.0 → 1.97.0 schema migration to run and no
   `litellm-migrate` unit. The previous "schema migration (plan §6.2)" manual gate no
   longer applies. If you later choose to retire the Postgres `litellm` DB, that is a
   data-retention action, not a runtime dependency.
7. **Codex poller (plan §13 #1).** `enableCodexUsage` is fork-only; upstream has no
   equivalent. Decision needed: drop Codex usage reporting, or reimplement a local
   poller. Not implemented.
8. **DB-data retirement — Nix side DONE, operator side manual.** The LiteLLM
   `postgresqlBackup` entry, `zfs-create-backup-litellm`, and `postgresqlBackup-litellm`
   binding have been removed from `modules/nas/litellm/default.nix`, and the
   `ensureDatabases`/`ensureUsers` for `litellm` are gone. Applying this does **not**
   drop the existing `litellm` DB/data — the operator must export (`pg_dump`) and drop
   (`DROP DATABASE`/`DROP ROLE`, `zfs destroy backup/litellm`) separately when ready
   (see the section above).
9. **Downstream acceptance (plan §12.7, Checks 1–10) and virtual-key inventory** are
   runtime operator actions; the `litellm` DB is not dropped until they pass.

## Secret rotation

Rotation is driven by `sops.secrets."litellm-env".restartUnits`, so the only operator
action is `sops edit` followed by a switch. `sops-nix` compares the previous and newly
decrypted content and acts **only on real changes**, so an unchanged secret restarts
nothing and repeated switches cannot loop.

| Edit | Units restarted | Effect |
| ---- | --------------- | ------ |
| `litellm-env` | `litellm-openai-api-key-env`, `litellm`, `karakeep-web`, `karakeep-workers`, `<backend>-paperless-gpt` | OPENAI_API_KEY file re-rendered from the new master key, gateway + clients restarted together |

`LITELLM_MASTER_KEY` has exactly one home: `litellm-env`. `litellm-openai-api-key-env.service`
extracts it and emits `OPENAI_API_KEY` for the gateway clients, so a single `sops edit` of
`litellm-env` moves gateway and clients together. There is no second copy of the key and
no `litellm-master-key` secret. The derivation enforces a strict contract: `litellm-env`
must contain exactly one simple `LITELLM_MASTER_KEY=sk-<ASCII token>` line (value chars
limited to `[A-Za-z0-9._~+/=-]`, no quotes/escapes/whitespace/CRLF/multiline); any
duplicate, quoted, escaped, or otherwise malformed form fails the unit closed rather than
emitting a malformed `OPENAI_API_KEY`.

`miniflux-curator.service` is intentionally **not** a restart target. It is a
timer-driven oneshot (07:15 / 23:15) that re-reads its `EnvironmentFile=` on every start,
so it picks up a rotated key on its next run. Listing it would make
`switch-to-configuration` `systemctl restart` an inactive oneshot, firing an off-schedule
curation run on every switch.

```bash
sudo nix-shell -p sops --run "sops edit secrets/<file>.yaml"   # rotate the value
sudo nixos-rebuild switch --flake .#nas                        # restarts follow automatically

# Confirm the rendered file actually advanced (mtime must be newer than the switch):
sudo stat -c '%y %n' /run/litellm-openai-api-key/openai-api-key-env
systemctl show -p ActiveEnterTimestamp litellm-openai-api-key-env.service litellm.service

# Prove gateway and clients agree on the master key without printing either:
sudo sh -c "grep '^LITELLM_MASTER_KEY=' /run/secrets/litellm-env | sha256sum"
sudo sha256sum /run/litellm-openai-api-key/openai-api-key-env
#   ^ the two hashes must match (identical single-line content). The first is the
#     master key line from litellm-env; the second is the rendered OPENAI_API_KEY file.

# Dry-run shows the pending restarts before committing to them:
sudo nixos-rebuild dry-activate --flake .#nas 2>&1 | grep -iE 'restart|reload'
```

## Verification

```bash
# Eval / build check (no switch; non-sudo):
nixos-rebuild dry-run --flake .#nas

# After the owner's sops edits and `sudo nixos-rebuild switch --flake .#nas`:
systemctl is-active litellm.service

# Rendered OPENAI_API_KEY env file for the gateway clients (-r-------- root root):
sudo ls -l /run/litellm-openai-api-key/openai-api-key-env

# litellm must NOT reference Postgres: no requires/after beyond the secret render.
systemctl show -p Requires -p After litellm.service
#   Expect no postgresql / litellm-db-role / litellm-env-combine references.

# Secret boundary of the rendered file: expect `drwx------ root root` on the
# directory and `-r-------- root root` on the file. Unprivileged read must fail.
sudo ls -ld /run/litellm-openai-api-key /run/litellm-openai-api-key/openai-api-key-env
cat /run/litellm-openai-api-key/openai-api-key-env   # must be "Permission denied"

curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://127.0.0.1:8090/v1/models \
  | grep -E 'gpt-5.6-|hy3|qwen'
sudo ls -l /var/lib/litellm/chatgpt/auth.json     # ChatGPT device-flow refresh
curl -s http://127.0.0.1:3000/api/public/health   # Langfuse
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" https://ai.homehub.tv/v1/models
```

## Cleanup note

The `litellm-nix` flake input is left in `flake.nix` (now unused) to keep `dry-run` safe
without a `nix flake update`. It can be removed once no longer referenced (requires
`nix flake update` to prune `flake.lock`).

The `plans/litellm-stateless-migration.md` source plan still describes the original
phased DB-retirement. This status doc supersedes it for the implemented runtime cutover;
the plan's Phase 6 (DB-data removal) remains a valid future operator checklist but is
gated on the data export/retention decision, not on any Nix change.

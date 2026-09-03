# LiteLLM Stateless Migration Plan

**Status:** Implementation plan — not yet executed.
**Target module:** `modules/nas/litellm`
**Scope:** Replace the forked `litellm-nix` package/module with upstream
`services.litellm` from `nixpkgs-unstable`, and move to master-key-only
client authentication (drop per-user virtual keys).

This document is the agreed plan. It names exact files, the ownership split of
current persistent state, the upstream-vs-fork boundary, the config diff, the
local systemd units that must replace fork behavior, the virtual-key decision,
discovery/acceptance commands, the cutover/rollback sequence, and the open
questions that need an explicit owner decision. No secret values are included.
Secrets are referenced only by their SOPS secret names.

---

## 1. Package / version decision

| Source            | Attribute                         | Version |
| ----------------- | --------------------------------- | ------- |
| Fork (`litellm-nix`) | `inputs.litellm-nix`            | 1.89.0  |
| `nixpkgs-unstable`   | `pkgs.litellm` (unstable)       | 1.97.0  |
| `nixpkgs` (stable)   | `pkgs.litellm` (25.11)          | 1.86.0  |

**Selected target:** `nixpkgs-unstable` `services.litellm` (1.97.0).

**Why unstable, not stable:**
- Stable (1.86.0) is *older* than the fork we already run (1.89.0), so it would
  be a downgrade and would not carry fork-era bug fixes or the
  `additional_drop_params` handling we already rely on.
- Unstable (1.97.0) is the newest of the three and is the only candidate that is
  both newer than the fork and shipped as a first-class `services.litellm`
  NixOS module (no flake input, no custom `litellm-nix` module import).
- The `nas` host runs the **stable** `nixpkgs` input today, so adopting the
  upstream module requires pinning LiteLLM to the **unstable** input
  (`pkgs-unstable.litellm` / `nixos-unstable` `services.litellm`) while leaving
  the rest of the host on stable. This is consistent with the repo's existing
  two-tier flake policy (stable for `nas`, unstable for `beast` desktop features).

> [tier:medium] Action: reference the unstable input explicitly for LiteLLM only (e.g.
> `services.litellm.package = pkgs-unstable.litellm;`), so the host stays on
> stable `nixpkgs` for everything else.

[acceptance]
- `services.litellm.package` is set to `pkgs-unstable.litellm` in the module.
- All other `nas` host options still resolve via the stable `nixpkgs` input.
[/acceptance]

---

## 2. Objective and non-goals

**Objective**
- Run LiteLLM via the upstream `services.litellm` module instead of the fork's
  `litellm-nix` module.
- Remove per-user virtual-key management from Postgres ("stateless" w.r.t. key
  issuance): all clients authenticate with the single SOPS-managed
  `LITELLM_MASTER_KEY`.
- Preserve existing routing (hosted ChatGPT `gpt-5.6-*`, OpenCode Go `hy3`,
  local llama-swap models) and the `ai.homehub.tv` → `127.0.0.1:8090` nginx
  reverse proxy unchanged.
- Preserve ChatGPT token storage on the filesystem and Langfuse tracing.

**Non-goals**
- Not changing the model list, routing topology, or nginx vhost.
- Not migrating LiteLLM to a different host.
- Not replacing Postgres *during the migration*. The `litellm` DB (spend logs /
  virtual keys) is kept only for a retention window to support rollback and a
  spend/key inventory export,   then **retired** (§9 Phase 6 / §10) — it is not
  retained indefinitely. Only *virtual key issuance* stops at cutover.
- Not changing Langfuse itself or its capture policy (flagged in §10, but out of
  scope to alter here).
- Not implementing per-consumer key rotation/revocation in this pass (see §7
  limitations).

---

## 3. Current state ownership split

Persistent state today is owned by three independent systems. The migration
must preserve or consciously re-home each.

| State                                            | Owner today                                  | Path / mechanism                                                  |
| ------------------------------------------------ | -------------------------------------------- | ----------------------------------------------------------------- |
| Virtual keys, users, spend logs / budgets        | **PostgreSQL** (`litellm` DB, `litellm` role) | `services.postgresql` `ensureDatabases`/`ensureUsers`; fork `manageLocalPostgresql = true` bootstraps the role + `LITELLM_DATABASE_PASSWORD` |
| ChatGPT OAuth tokens (device-flow refresh)       | **Filesystem**                               | `/var/lib/litellm/chatgpt/auth.json` (written by upstream LiteLLM's ChatGPT authenticator — device-flow OAuth + lazy token refresh; `requireChatgptAuth`/`enableChatgptLogin` were fork *NixOS module* gating options, not the auth mechanism itself) |
| Traces / observability                           | **Langfuse** (host loopback `127.0.0.1:3000`) | `langfuse_otel` callback; `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = span_and_event` |

State directory (`stateDir`): `/var/lib/litellm` — shared by fork and upstream,
so `auth.json` and any local cache survive the switch as long as we keep the
same `stateDir`.

---

## 4. Upstream vs fork distinction (must be correct)

This is the crux of the migration and the most common error source.

**Upstream `services.litellm` (what we are moving TO) provides:**
- The NixOS module: `services.litellm.enable`, `host`, `port`, `settings`
  (rendered to YAML), `environment`, `environmentFile`, `stateDir`,
  `openFirewall`, `package`.
- It runs the stock LiteLLM proxy + admin. It performs DB schema migrations on
  (re)start as part of the service (verify with `systemctl cat litellm` after
  switch — see §9).
- Its **ChatGPT authenticator** does the device-flow OAuth, lazy token refresh,
  and writes `/var/lib/litellm/chatgpt/auth.json`. This is the same
  filesystem-owned token store we already rely on; upstream owns it natively,
  the fork did not add it.

**The fork (`litellm-nix`, what we are moving FROM) additionally provided:**
- Nix/module wiring that **managed the local Postgres role + password**
  (`manageLocalPostgresql = true`, `databaseEnvFile`). **Upstream does not.**
- `configFile`, `envFiles` (a *list* of env files), `extraEnvironment`,
  `databaseEnvFile`, `requireChatgptAuth`, `enableChatgptLogin`,
  `enableCodexUsage` — fork-only attributes. **None exist in upstream.**
- A dedicated **`litellm-migrations.service`** / startup ordering for Prisma.
  Upstream folds this into the main service.
- A **gate** for ChatGPT login (the `requireChatgptAuth`/`enableChatgptLogin`
  switches) — upstream handles ChatGPT login via its own authenticator config
  instead.
- A **Codex poller** (`enableCodexUsage`) that reports/refreshes Codex usage.
  **Upstream has no equivalent.** This is a genuine capability loss, not a
  rename (see §11, decision #1).

**Consequence:** the migration is not a rename of the attribute set. We must
re-create the Postgres role/password wiring and the multi-file env injection
locally, because upstream intentionally does not do those.

---

## 5. Exact configuration changes (by existing path)

No Nix is modified by this document — these are the edits to make at execution
time. All paths are relative to repo root.

### 5.1 `modules/nas/litellm/default.nix`

[tier:medium] **Remove the fork import:**
```nix
# DELETE:
imports = [ inputs.litellm-nix.nixosModules.default ];
```
(Upstream `services.litellm` is built into `nixpkgs`, no import needed.)

[acceptance]
- `modules/nas/litellm/default.nix` no longer imports `inputs.litellm-nix.nixosModules.default`.
- `nixos-rebuild dry-run --flake .#nas` parses without an unknown-module error.
[/acceptance]

[tier:medium] **Replace the entire `services.litellm-nix = { … }` block** (lines ~177–218)
with an upstream-shaped block. Key mappings:

| Fork attribute (removed)            | Upstream replacement                                                        |
| ----------------------------------- | --------------------------------------------------------------------------- |
| `host = "127.0.0.1"`                 | `services.litellm.host = "127.0.0.1";`                                      |
| `port = 8090`                       | `services.litellm.port = 8090;`                                             |
| `requireChatgptAuth` / `enableChatgptLogin` | Configure ChatGPT authenticator via `services.litellm.settings.litellm_settings` (upstream-owned; verify option name against 1.97.0 docs) |
| `enableCodexUsage`                  | **No upstream equivalent** — see §11 decision #1                            |
| `configFile = litellmConfig`        | `services.litellm.settings = <YAML attrset>` (the same content, expressed as Nix) |
| `manageLocalPostgresql = true`      | **Removed** — replace with local Postgres role unit (§6)                    |
| `databaseEnvFile`                   | `services.litellm.environmentFile = …` (consolidated, §5.3)                 |
| `envFiles = [ … ]` (list)           | `services.litellm.environmentFile` (single) + `services.litellm.environment` for non-secrets (§5.3) |
| `extraEnvironment`                  | `services.litellm.environment` (non-secret vars only)                       |

`litellmConfig` (the `yaml.generate "litellm-config.yaml" { … }`) becomes the
value of `services.litellm.settings`. During the transition cutover the
`general_settings.master_key` and `database_url` remain `os.environ/…`
references; `master_key` is supplied by `litellm-env` and `database_url` by
`litellm-database-env` (§5.3). **In the DB-free phase (§9 Phase 5) the
`general_settings.database_url` reference is removed entirely** so upstream
LiteLLM runs without a database — until then the config still points at Postgres
and the DB must remain attached.

[acceptance]
- The `services.litellm-nix` attribute set is fully removed from `default.nix`.
- `services.litellm.host = "127.0.0.1"` and `services.litellm.port = 8090` are set.
- `services.litellm.settings` carries the former `litellmConfig` content (model list, `gpt-5.6-*`, `hy3`).
- `nixos-rebuild dry-run --flake .#nas` evaluates the new module.
[/acceptance]

**Keep unchanged:** `services.postgresql` `ensureDatabases`/`ensureUsers`,
`services.postgresqlBackup`, the `zfs-create-backup-litellm` unit, the
`postgresqlBackup-litellm` binding unit, the `sops.secrets` declarations, the
nginx `ai.homehub.tv` vhost (still `port = 8090`), and `models.nix` (now
OpenCode-only; see §5.2).

### 5.2 `modules/nas/litellm/models.nix`

Role changed after this plan: `models.nix` is now the **OpenCode-only** static
catalog (consumed by `users/cody/harness/opencode`). LiteLLM no longer derives
its upstream `model_list` from it; instead `default.nix` serves ChatGPT-backed
`gpt-5.6-*` via explicit `chatgpt/gpt-5.6-*` routes and `hy3` via its
distinct OpenCode Go route, with llama-swap entries appended last. The model ID
list (`gpt-5.6-luna/-terra/-sol`, `hy3`) is preserved.

### 5.3 Secret / env injection consolidation

Today four SOPS-backed inputs feed the fork: `litellm-env`,
`litellm-database-env` (DB role password / `DATABASE_URL`), `litellm-langfuse-env`,
and the `opencode-go-api-key-env` template. Upstream has a
**single** `environmentFile`. To keep one authoritative source per concern, the
secrets are kept **separate during the transition**; they are merged only at the
single point LiteLLM reads its `environmentFile`, via the transitional combine
unit in §6.4:

- [tier:medium] **`litellm-env`** holds the gateway/provider/Langfuse secrets
   **only** — **no `DATABASE_URL`**:
   `LITELLM_MASTER_KEY`, `OPENCODE_GO_API_KEY`, `LANGFUSE_PUBLIC_KEY`,
   `LANGFUSE_SECRET_KEY`.
   (Move the Langfuse and OpenCode-Go values into the existing `litellm-env`
   secret via `sops edit`; fold `litellm-langfuse-env` and the
   `opencode-go-api-key-env` template into `litellm-env` and delete them once
   migrated.)

- [tier:medium] **`litellm-database-env` is the single authoritative source for
   `DATABASE_URL` and `LITELLM_DATABASE_PASSWORD`** during the transition. It is
   read only by the DB transition configuration (the §6.1 role unit and the
   LiteLLM `DATABASE_URL` reference); it is **not** folded into `litellm-env` and
   must never be described as carrying the master key. Reuse the existing secret —
   **do not add a new `litellm-db-password` secret**. It is removed entirely at
   the DB-free cutover (§9 Phase 5 / §6.4), not at the transition cutover.

[acceptance]
- `litellm-env` carries `LITELLM_MASTER_KEY`, `OPENCODE_GO_API_KEY`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY` and contains **no** `DATABASE_URL`.
- `litellm-database-env` is the sole source of `DATABASE_URL` and `LITELLM_DATABASE_PASSWORD` during the transition; it is not merged into `litellm-env`.
- `litellm-langfuse-env` and `opencode-go-api-key-env` are folded into `litellm-env` and removed.
- The existing `litellm-database-env` secret is reused (not replaced by a new `litellm-db-password` secret).
[/acceptance]

- [tier:medium] **Non-secret vars go in `services.litellm.environment`:**
  `STORE_PROMPTS_IN_SPEND_LOGS`, `PYTHONPATH` (OTel packages),
  `LANGFUSE_HOST`, `LANGFUSE_OTEL_HOST`, `LANGFUSE_TRACING_ENVIRONMENT`,
  `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`.

[acceptance]
- `services.litellm.environment` lists the non-secret vars (`STORE_PROMPTS_IN_SPEND_LOGS`, `PYTHONPATH`, `LANGFUSE_HOST`, `LANGFUSE_OTEL_HOST`, `LANGFUSE_TRACING_ENVIRONMENT`, `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`).
- `PYTHONPATH` still references the `openTelemetryPython` derivation.
[/acceptance]

- [tier:medium] **Wire during transition:** `services.litellm.environmentFile`
   points at the transitional combined env file produced by §6.4 (built from
   `litellm-env` + `litellm-database-env`), so LiteLLM receives the master key,
   provider/Langfuse keys, **and** `DATABASE_URL` from their respective
   single-source secrets. At the DB-free cutover (§9 Phase 5) the combine unit is
   removed and `environmentFile` reverts to
   `config.sops.secrets."litellm-env".path` alone.

> Note: the `PYTHONPATH` for `langfuse_otel` (the `openTelemetryPython` derivation
> in the current module) is still required and must be carried into `environment`.

[acceptance]
- During transition, `services.litellm.environmentFile` points at the §6.4 combined env file; `litellm-env` supplies the master/provider/Langfuse vars and `litellm-database-env` supplies `DATABASE_URL` (no `DATABASE_URL` in `litellm-env`).
- `sops.secrets."litellm-env"` is declared in the module.
- At DB-free cutover, `environmentFile` reverts to `config.sops.secrets."litellm-env".path` and `litellm-database-env` is no longer referenced.
[/acceptance]

---

## 6. Required local replacement systemd units

Because upstream does not manage local Postgres or run `manageLocalPostgresql`,
we must supply the equivalent locally.

### 6.1 Postgres role + password bootstrap (replaces `manageLocalPostgresql`)
Keep `services.postgresql.enable`, `ensureDatabases = [ "litellm" ]`,
`ensureUsers = [ { name = "litellm"; ensureDBOwnership = true; } ]`.

[tier:medium] Add a oneshot that applies the DB password from the SOPS secret to the `litellm`
role and is ordered before LiteLLM. This unit is **transitional** — it is removed
in the DB-free phase (§9 Phase 5, §6.4) once LiteLLM runs without a database.
```
systemd.services."litellm-db-role" = {
  description = "Apply litellm Postgres role password from SOPS (transitional)";
  wantedBy = [ "multi-user.target" ];
  # Run only after the DB is up AND the DB secret has been materialized by sops-nix,
  # and before LiteLLM starts.
  after    = [ "postgresql.service" "sops-nix.service" ];
  requires = [ "postgresql.service" "sops-nix.service" ];
  before   = [ "litellm.service" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    # Connect as the postgres superuser via peer auth (no password prompt, no
    # secret value echoed). psql targets the litellm DB explicitly.
    User = "postgres";
  };
  script = ''
    . ${config.sops.secrets."litellm-database-env".path}
    ${pkgs.postgresql}/bin/psql -d litellm -v ON_ERROR_STOP=1 \
      -c "ALTER ROLE litellm WITH LOGIN PASSWORD '$LITELLM_DATABASE_PASSWORD';"
  '';
};
```
[acceptance]
- A `systemd.services."litellm-db-role"` oneshot exists, ordered `before = [ "litellm.service" ]` and `after = [ "postgresql.service" "sops-nix.service" ]`, with `requires` on both.
- The role `litellm` has `LOGIN` and the password from `litellm-database-env` applied after a switch (run as `User = "postgres"` with an explicit `-d litellm` target, so peer auth succeeds and no secret value is echoed).
- No new `litellm-db-password` SOPS secret is introduced.
- **Cold-boot test required:** after the first switch, a full cold boot (or `systemctl stop litellm postgresql; systemctl start postgresql; systemctl start litellm-db-role; systemctl start litellm`) proves the role password is applied and `litellm.service` starts successfully against the DB; the journal shows the `ALTER ROLE` and a clean LiteLLM startup.
- The unit is documented as transitional and is removed in the DB-free phase (§9 Phase 5).
[/acceptance]

`DATABASE_URL` is supplied by `litellm-database-env` (the single source of truth
for DB creds during transition), using that same password
(`postgresql://litellm:<pw>@/litellm?host=/run/postgresql` or `host=127.0.0.1`).
Reuse the existing `litellm-database-env` SOPS secret (it already carries
`LITELLM_DATABASE_PASSWORD`) — do **not** add a new `litellm-db-password` secret.
This unit and the `DATABASE_URL` wiring are **transitional** and are removed in
the DB-free phase (§9 Phase 5, §6.4).

### 6.2 Migrations
[tier:medium] Upstream `services.litellm` runs schema migrations on start. **Verify** after
the first switch (`systemctl cat litellm` and journal) that migrations run.

[acceptance]
- After the first switch, `systemctl cat litellm` (and the journal) shows schema migration activity on start.
- `litellm` starts cleanly with a migrated schema.
[/acceptance]

[tier:medium] If upstream does *not* auto-migrate, add a `litellm-migrate` oneshot
(`litellm --run_migrations` against `DATABASE_URL`) ordered `before = [
"litellm.service" ]`.

[acceptance]
- A `litellm-migrate` oneshot exists ordered `before = [ "litellm.service" ]`.
- Running `litellm --run_migrations` against `DATABASE_URL` reports success (or a no-op when the schema is current).
[/acceptance]

### 6.3 Preserved units (no change)
`zfs-create-backup-litellm`, `postgresqlBackup-litellm` binding, and the nginx
vhost remain exactly as-is.

### 6.4 Transitional env-file combine (DB transition only)

Upstream `services.litellm` accepts a single `environmentFile`, but the transition
keeps two separate SOPS secrets (§5.3): `litellm-env` (master/provider/Langfuse
keys) and `litellm-database-env` (`DATABASE_URL` + role password). Add a
transitional oneshot that concatenates the two decrypted secret files into one
env file LiteLLM reads:

[tier:medium]
```
systemd.services."litellm-env-combine" = {
  description = "Combine litellm-env and litellm-database-env into one environmentFile (transitional)";
  wantedBy = [ "multi-user.target" ];
  after    = [ "sops-nix.service" ];
  requires = [ "sops-nix.service" ];
  before   = [ "litellm.service" ];
  serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
  script = ''
    mkdir -p /run/litellm
    cat ${config.sops.secrets."litellm-env".path} \
        ${config.sops.secrets."litellm-database-env".path} \
      > /run/litellm/litellm.env
  '';
};
```
Then `services.litellm.environmentFile = "/run/litellm/litellm.env";`.

This unit is **transitional**: in the DB-free phase (§9 Phase 5) it is deleted,
`litellm-database-env` is removed, and `environmentFile` reverts to
`config.sops.secrets."litellm-env".path`.

[acceptance]
- A `litellm-env-combine` oneshot exists, `after`/`requires` `sops-nix.service` and `before` `litellm.service`, writing a combined env file consumed by `services.litellm.environmentFile`.
- `litellm-env` and `litellm-database-env` remain the separate single sources; the combine step only merges them for the one `environmentFile` LiteLLM accepts.
- The unit is documented as transitional and removed in the DB-free phase (§9 Phase 5), after which `environmentFile` points at `litellm-env` alone.
[/acceptance]

---

## 7. Virtual-key decision (SOPS master key only)

**Decision: authenticate all clients with the single `LITELLM_MASTER_KEY`
(from the `litellm-env` SOPS secret) as a Bearer token. Do not issue or rely on
per-user virtual keys stored in Postgres.**

Rationale: the agreed "stateless" goal removes key lifecycle management from the
proxy. Every current consumer (Hermes, OpenCode `hy3`, karakeep, Open-WebUI)
already sends the master key as a Bearer token (per `Local-AI-Infrastructure.md`
"Client auth"). No consumer depends on a distinct virtual key today.

**Limitations (explicit):**
- No per-consumer spend attribution or per-key revocation. All usage is
  attributed to the master key.
- Revoking access means rotating the master key and updating *every* client
  (see rotation below) — there is no scoped revocation.
  - Spend/budget *logs* accumulate in Postgres during the retention window (the
    `litellm` DB is kept only until retirement, §9 Phase 6 / §10); after that the
    DB is retired. Key *issuance* stops at cutover.

[tier:fast] **Inventory query (run before cutover, §8):** enumerate existing keys/users so
we know nothing depends on them and can notify/export if needed:
```bash
sudo -u postgres psql -d litellm -c '\dt'          # confirm schema/table names
sudo -u postgres psql -d litellm -c \
  "SELECT key_name, key_alias, user_id, expires_at FROM litellm_verificationtoken;"
# table name varies by LiteLLM version; if the above fails, inspect \dt output.
```

**Rotation approach (post-cutover, when needed):**
1. [tier:medium] Generate a new master key value; update only the `litellm-env` SOPS secret
   (`sops edit` on the `nas` host secrets).

   [acceptance]
   - A new master key value is generated and written only to the `litellm-env` SOPS secret.
   - `sops edit` on the `nas` host secrets succeeds and the secret re-encrypts.
   [/acceptance]

2. [tier:medium] `sudo sops updatekeys` / re-decrypt so the new file lands at the secret path.

   [acceptance]
   - `sudo sops updatekeys` completes and the decrypted `litellm-env` file at the secret path contains the new key.
   [/acceptance]

3. [tier:medium] `systemctl restart litellm` (re-reads `environmentFile`).

   [acceptance]
   - `systemctl restart litellm` succeeds; the service is `active` and re-reads `environmentFile`.
   [/acceptance]

4. [tier:medium] Update the master key in each client config (OpenCode `hy3`, Hermes,
   karakeep, Open-WebUI) from the same SOPS source.

   [acceptance]
   - Each client (OpenCode `hy3`, Hermes, karakeep, Open-WebUI) is updated to the same rotated master key from the SOPS source.
   - After restart the old key is rejected and the new key authenticates requests.
   [/acceptance]

5. Old key is immediately invalid on restart — coordinate the client updates
   with the restart.

---

## 8. Pre-cutover discovery & acceptance commands

[tier:fast] Run on `nas` (some require `sudo`, which the executing operator provides — this
plan does not run them):

**Discovery**
```bash
# 1. Confirm current fork is active and listening
systemctl is-active litellm-nix.service
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://127.0.0.1:8090/v1/models

# 2. Inventory virtual keys / users (see §7 query)
sudo -u postgres psql -d litellm -c "SELECT key_alias, user_id FROM litellm_verificationtoken;"

# 3. Snapshot current ChatGPT token store (filesystem-owned)
sudo ls -l /var/lib/litellm/chatgpt/auth.json
sudo stat -c '%y' /var/lib/litellm/chatgpt/auth.json     # last refresh time

# 4. Confirm which consumers use a non-master virtual key (grep client configs)
#    OpenCode harness: users/cody/harness/opencode ; Hermes; karakeep; Open-WebUI
```

[tier:medium] Take a fresh DB backup before any change:
```bash
# 5. Fresh DB backup before any change
sudo systemctl start postgresqlBackup-litellm
ls -l /mnt/litellm-backups
```

[acceptance]
- `postgresqlBackup-litellm` ran and a new dump exists under `/mnt/litellm-backups`.
- The pre-cutover backup predates any config change.
[/acceptance]

[tier:medium] **Acceptance (after cutover, §9)**
```bash
systemctl is-active litellm.service
systemctl cat litellm | grep -i migrate        # confirm migration handling
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://127.0.0.1:8090/v1/models \
  | grep -E 'gpt-5.6-|hy3|qwen'
# ChatGPT device-flow login produces a refreshed token file:
sudo ls -l /var/lib/litellm/chatgpt/auth.json
# Langfuse receives traces:
curl -s http://127.0.0.1:3000/api/public/health   # or check Langfuse UI traces
# nginx vhost still proxies:
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" https://ai.homehub.tv/v1/models
```

[acceptance]
- `systemctl is-active litellm.service` reports `active`.
- `systemctl cat litellm` shows migration handling on start.
- `GET /v1/models` (loopback and `https://ai.homehub.tv`) returns `gpt-5.6-*` / `hy3`.
- `/var/lib/litellm/chatgpt/auth.json` exists and is refreshed via device-flow login.
- Langfuse `/api/public/health` responds (or traces appear in the UI).
[/acceptance]

[tier:medium] Precondition: `nixos-rebuild dry-run --flake .#nas` must succeed before the real switch.

---

## 9. Phased implementation / cutover / rollback

**Two cutovers, not one.** The *transition cutover* (Phase 2) switches the
gateway to upstream LiteLLM **while Postgres is still attached** — virtual keys /
spend and a clean rollback path are preserved. The *final DB-free cutover* happens
later (Phase 5 → Phase 6): only after the LiteLLM configuration is rebuilt to run
without a database, soaked, and proven by the full acceptance suite is the
Postgres `litellm` DB actually retired. The database is **not** removable while the
LiteLLM config still points at it.

[tier:fast] **Phase 0 — Discovery (do first):** run §8 discovery. Confirm no consumer uses
a per-user virtual key. Capture `auth.json` mtime and a DB backup.

**Phase 1 — Prepare (config only, service still fork):**
- [tier:medium] Edit `modules/nas/litellm/default.nix` per §5 (remove fork import/block, add
  `services.litellm`, local units per §6).

  [acceptance]
  - `default.nix` no longer imports the fork and declares `services.litellm` plus the §6 local units.
  - `nixos-rebuild dry-run --flake .#nas` evaluates the edited module.
  [/acceptance]

- [tier:medium] Consolidate SOPS secrets per §5.3 (reuse `litellm-database-env`; do **not** add
  a new `litellm-db-password` secret).

  [acceptance]
  - `litellm-env` is the single combined env secret; `litellm-database-env` is reused, not replaced.
  - `sops edit` on the `nas` host succeeds and `updatekeys` lands the files.
  [/acceptance]

- [tier:medium] `nixos-rebuild dry-run --flake .#nas` — must pass.

  [acceptance]
  - `nixos-rebuild dry-run --flake .#nas` exits 0 with no eval/build errors.
  [/acceptance]

- Keep `services.litellm-nix.enable = true` for now (both modules present but
  only fork active; they share port 8090, so do **not** enable upstream yet).

**Phase 2 — Cutover:**
- [tier:medium] Set `services.litellm-nix.enable = false` and `services.litellm.enable = true`.

  [acceptance]
  - `services.litellm-nix.enable = false` and `services.litellm.enable = true` in the module.
  [/acceptance]

- [tier:medium] `sudo nixos-rebuild switch --flake .#nas`.

  [acceptance]
  - The switch completes; `litellm.service` is active and `litellm-nix.service` is stopped.
  [/acceptance]

- [tier:medium] Verify §8 acceptance. The shared `stateDir` (`/var/lib/litellm`) and Postgres
  `litellm` DB are reused, so `auth.json` and spend logs persist.

  [acceptance]
  - All §8 acceptance checks pass (service active, models returned, `auth.json` present, Langfuse health, nginx proxy).
  - `auth.json` and spend logs persist across the switch.
  [/acceptance]

[tier:medium] **Phase 3 — Verify & soak:** let it run; confirm Langfuse traces and a
successful ChatGPT device-flow refresh lands in `auth.json`.

[acceptance]
- Langfuse shows traces for proxied requests during the soak window.
- A successful ChatGPT device-flow refresh updates `/var/lib/litellm/chatgpt/auth.json`.
[/acceptance]

**Phase 4 — Rollback (if Phase 2/3 fails):**
- [tier:medium] Revert `default.nix` to the fork block (`services.litellm-nix.enable = true`,
  `services.litellm.enable = false`), `sudo nixos-rebuild switch`.

  [acceptance]
  - The switch restores the fork block; `litellm-nix.service` is active and `litellm.service` stopped.
  [/acceptance]

- [tier:medium] **DB caveat:** if upstream ran a schema migration the fork cannot read,
  restore the pre-cutover Postgres dump first:
  ```bash
  sudo systemctl stop litellm-nix.service
  sudo -u postgres psql -d litellm -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  sudo -u postgres bash -c 'zstd -dc /mnt/litellm-backups/<pre-cutover-dump>.sql.zst | psql -d litellm'
  sudo systemctl start litellm-nix.service
  ```

  [acceptance]
  - After restore, `litellm-nix.service` starts and reads the pre-cutover schema without migration errors.
  - The restored dump matches `/mnt/litellm-backups/<pre-cutover-dump>.sql.zst`.
  [/acceptance]
  - Because `stateDir` is shared, `auth.json` is intact either way.

[tier:medium] **Phase 5 — Build & soak the DB-free (stateless) configuration (mandatory
before DB retirement):** only after the transition cutover is verified and soaked
(§9 Phase 3) **and** the downstream consumer acceptance is complete (the §12.1
discovery gate is recorded and the §12.7 end-to-end checklist, Checks 1–10, has
fully passed) do we change the LiteLLM configuration to be database-free. **Do not
claim the database is removable while the LiteLLM config still points at it.** The
DB is retained and continues to run during this phase; only the *configuration* is
switched to DB-less. Tasks:
- [tier:medium] Remove `general_settings.database_url` from the rendered LiteLLM
   config (`services.litellm.settings`); upstream LiteLLM then runs without a
   database.
   [acceptance]
   - `services.litellm.settings` no longer contains `general_settings.database_url`; the config is DB-less.
   [/acceptance]
- [tier:medium] Remove `DATABASE_URL` and all DB-specific environment/wiring: delete
   the `litellm-env-combine` unit (§6.4) and `litellm-db-role` unit (§6.1), drop
   the `litellm-migrate` oneshot if present (§6.2), and revert
   `services.litellm.environmentFile` to
   `config.sops.secrets."litellm-env".path`. Remove the `litellm-database-env`
   SOPS secret and stop referencing it anywhere in the module.
   [acceptance]
   - The `litellm-env-combine` and `litellm-db-role` units and any `litellm-migrate` oneshot are removed; `environmentFile` points at `litellm-env` alone.
   - The `litellm-database-env` SOPS secret is removed and no longer referenced by the module.
   - No `DATABASE_URL` remains in any LiteLLM env/config.
   [/acceptance]
- [tier:medium] Set/verify the DB-less upstream LiteLLM behavior: confirm upstream
   1.97.0 starts without `database_url` (no migration attempt, clean startup) and
   that virtual-key auth is fully replaced by the master key.
   [acceptance]
   - A `nixos-rebuild dry-run --flake .#nas` and the first switch show LiteLLM starting cleanly with no DB connection attempt and no `database_url` referenced.
   [/acceptance]
- [tier:medium] Build and **soak** the no-DB configuration under real traffic
   (routing, ChatGPT device-flow refresh into `auth.json`, Langfuse traces); the
   gateway must stay `active` and serve all models.
   [acceptance]
   - The no-DB gateway runs through a soak window with real traffic and stays `active`; ChatGPT `auth.json` refreshes and Langfuse traces arrive.
   [/acceptance]
- [tier:medium] **Gate to Phase 6:** DB retirement may proceed **only** after this
   DB-free configuration passes the gateway acceptance (§8) **and** the full
   downstream acceptance suite (§12.7, Checks 1–10). Until both pass, the Postgres
   `litellm` DB keeps running and is not dropped.
   [acceptance]
   - Both the §8 gateway acceptance and the §12.7 Checks 1–10 have fully passed against the DB-free configuration before Phase 6 begins.
   [/acceptance]

**Phase 6 — Retire LiteLLM DB (after the DB-free configuration passes):** only
after Phase 5 is verified, an exported spend/key inventory exists, and with
explicit owner sign-off:
- [tier:medium] Stop LiteLLM, drop the `litellm` Postgres DB / role, and remove the
   `zfs-create-backup-litellm` / `postgresqlBackup-litellm` DB backup units. (The
   `litellm-database-env` SOPS secret and the DB-specific units were already
   removed in Phase 5, when the config went DB-less.)

   [acceptance]
   - LiteLLM is stopped and the `litellm` Postgres DB/role is dropped.
   - The DB-specific backup units (`zfs-create-backup-litellm`, `postgresqlBackup-litellm`) are removed.
   - The `litellm-database-env` SOPS secret is already removed (in Phase 5) and no longer referenced by the module.
   - No consumer still depends on `DATABASE_URL` (verified before retirement).
   [/acceptance]

- Langfuse remains the long-term trace store; LiteLLM spend/key state is gone by
   design (stateless goal). Confirm no consumer still depends on `DATABASE_URL`.

---

## 10. DB deletion, retention & backup sequencing

- **Retire, don't retain indefinitely.** Stateless refers to *key issuance* at
  cutover, but the agreed goal is to retire the `litellm` Postgres DB (spend logs
  / virtual keys) after a retention window — not keep it forever. Keep the DB only
  through the retention window to support rollback (§9 Phase 4) and a spend/key
  inventory export, then drop it (§9 Phase 6).
- **Retention:** keep the pre-cutover backup (`/mnt/litellm-backups`) for at
  least 14 days after a verified cutover before allowing normal rotation to
  expire it; the live `litellm` DB itself is retired once the retention window
  passes and the owner signs off.
- **Backup sequencing:** a fresh `postgresqlBackup-litellm` (§8 step 5) is
  mandatory *before* Phase 2. The ZFS dataset unit guarantees the dump lands on
  the mounted backup pool, not the parent dir.
- **Destructive steps (if ever needed later):** only after a verified, soaked
  cutover AND an exported spend/key inventory — and only with an explicit
  owner sign-off. Deletion is irreversible; restoration requires the ZFS dump.
- **Downstream gate:** virtual-key retirement and DB deletion additionally require
  the §12.1 discovery record and a fully passing §12.7 checklist; until both hold,
  the retention window continues and nothing is dropped.

---

## 11. Security / privacy notes (Langfuse prompt capture)

These settings are carried over unchanged, but the migration is the right moment
to acknowledge their privacy impact:

- `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = span_and_event` makes
  LiteLLM send **full prompt and completion content** to Langfuse (not truncated
  summaries). Any secret or PII passed in a prompt/response is captured in
  Langfuse.
- `STORE_PROMPTS_IN_SPEND_LOGS = "true"` stores prompt/completion text in the
  Postgres spend logs.
- Langfuse is reachable only on host loopback (`127.0.0.1:3000`); it is not
  exposed externally. Access control is whatever Langfuse's own auth enforces.
- [tier:medium] **Action item (not blocking migration):** confirm Langfuse project access is
  restricted and decide whether full-content capture should remain on. Flag to
  owner; do not silently change.

  [acceptance]
  - Langfuse project access restriction is confirmed (or a decision to keep it is recorded).
  - The owner is flagged; full-content capture is not changed silently.
  [/acceptance]

---

## 12. Downstream consumer migration (client → master key)

§9 only re-homes the **gateway**. Every client that authenticates to
`https://ai.homehub.tv/v1`, plus the clients that currently reach llama-swap
directly and should move behind the gateway, needs its own migration step, its
own regression test, and — where the credential lives outside Nix — an explicit
user-owned action (§12.6). This section does not modify Nix, the flake, or SOPS;
it records the edits and operator actions to perform at execution time. No key
values appear here, and no key value may be written into the Nix store, the
generated OpenCode config, or this repo.

**Sequencing rule:** §12.1 (discovery gate) blocks everything else in §12, and
the §12.7 checklist blocks virtual-key retirement and DB retirement (§9 Phase 6,
§10).

### 12.1 Runtime discovery gate (blocking)

Nothing in §12 may be edited, and no virtual key or DB may be retired, until the
four records below exist.

[tier:fast] Record the live runtime facts (read-only):
```bash
# a. OpenCode: locate the *generated* config the session actually loads, and
#    where its current credential is stored (harness source:
#    users/cody/harness/opencode/default.nix)
systemctl --user cat opencode 2>/dev/null || true   # if session-managed
ls -l ~/.config/opencode/ ~/.local/share/opencode/ 2>/dev/null

# b. OpenWebUI: in the admin UI (Settings -> Connections -> OpenAI) record the
#    endpoint URL and the listed model IDs. Record only *that* a key is set.
#    Never print, copy, export, or paste the key value.

# c. Enumerate every established client of the gateway and of llama-swap
sudo ss -tnp state established '( sport = :8090 )'
sudo ss -tnp state established '( sport = :8081 )'

# d. Full virtual-key / user inventory (§7 query) exported to an operator-held
#    record (outside this repo)
```

[acceptance]
- The OpenCode generated-config path and the location of its current credential are recorded; the credential value is not copied into the repo or this document.
- The OpenWebUI admin OpenAI connection endpoint and its model list are recorded; no key value is printed, exported, or pasted anywhere.
- Established peers on `:8090` and `:8081` are enumerated, and each is classified as (i) gateway client to migrate (§12.4), (ii) intentional direct llama-swap bypass to preserve (§12.5), or (iii) unknown.
- The virtual-key/user inventory from §7 is exported and held by the operator.
- **Gate:** no virtual key is deleted and the `litellm` DB is not dropped (§9 Phase 6) until all four records exist and no peer remains in class (iii) — remaining classifications are an owner decision (§13 decision #6).
[/acceptance]

### 12.2 OpenCode harness (`users/cody/harness/opencode`)

Confirmed current state:
- `users/cody/harness/opencode/default.nix:72-93` declares provider `litellm`
  with `npm = "@ai-sdk/openai-compatible"`, `baseURL = "https://ai.homehub.tv/v1"`,
  and a model list derived from `modules/nas/litellm/models.nix`.
- There is **no API key in the Nix config**. The source comment states the
  credential in use today is a **manually created client-side virtual key**.
- `users/cody/harness/opencode/tools/model-router/default.nix:16-30` maps tiers
  to `litellm/gpt-5.6-luna`, `litellm/hy3`, and `litellm/gpt-5.6-terra` and does
  **no authentication of its own** — it inherits the provider credential.

OpenCode supports environment substitution in provider options
(`options.apiKey = "{env:LITELLM_API_KEY}"`, per the official OpenCode config
docs), which keeps the value out of the Nix store and out of the generated config.

[tier:medium] Set the `litellm` provider's `options.apiKey = "{env:LITELLM_API_KEY}"`
in `users/cody/harness/opencode/default.nix`. Leave `npm`, `baseURL`, and the
`models.nix`-derived model list unchanged.

[acceptance]
- The `litellm` provider declares `options.apiKey = "{env:LITELLM_API_KEY}"`; no literal key appears in Nix or in the generated config.
- `npm`, `baseURL` (`https://ai.homehub.tv/v1`), and the model list from `modules/nas/litellm/models.nix` are byte-identical to before.
- `nixos-rebuild dry-run --flake .` evaluates the harness change.
[/acceptance]

[tier:heavy] **Owner decision (pre-implementation):** select the mechanism that
delivers `LITELLM_API_KEY` from SOPS into Cody's interactive OpenCode session
**without** placing the value in the Nix store, in the generated config, or in a
world-readable file. No mechanism is chosen or assumed by this plan (§13
decision #5); do not implement one before the decision is recorded.

[acceptance]
- A single delivery mechanism is chosen and recorded, with its trust boundary stated (who/what can read the decrypted value, and at which point in session startup it becomes available).
- The chosen mechanism demonstrably keeps the value out of the Nix store, out of the generated OpenCode config, and out of git.
[/acceptance]

[tier:medium] Implement and validate the chosen mechanism, then restart the
OpenCode session so it re-reads the provider config and the environment.

[acceptance]
- In a fresh OpenCode session, `LITELLM_API_KEY` resolves to the SOPS-sourced value and the `litellm` provider authenticates against `https://ai.homehub.tv/v1`.
- The decrypted value is not present in the Nix store, the generated config, shell history, or git.
- The previous session no longer serves requests with the old credential after restart.
[/acceptance]

[tier:medium] Test each model-router tier route end to end (model names are
**unchanged**: `litellm/gpt-5.6-luna`, `litellm/hy3`, `litellm/gpt-5.6-terra`).

[acceptance]
- A fast-tier request routes to `litellm/gpt-5.6-luna` and returns a completion.
- A medium-tier request routes to `litellm/hy3` and returns a completion.
- A heavy-tier request routes to `litellm/gpt-5.6-terra` and returns a completion.
- `tools/model-router/default.nix:16-30` model IDs are unchanged, and the router still performs no authentication of its own.
[/acceptance]

[tier:medium] Only **after** the four checks above pass, retire (delete) the
manually created client-side virtual key.

[acceptance]
- The old OpenCode virtual key is deleted only after direct-model and all three tier routes have succeeded with the master key.
- After deletion, a fresh OpenCode session still succeeds (proving it no longer depends on the retired key).
[/acceptance]

### 12.3 OpenWebUI (`modules/nas/open-webui.nix`) — runtime state, not Nix

Confirmed current state: `modules/nas/open-webui.nix:9-41` sets the state
directory `/var/lib/open-webui`, declares **no** LiteLLM connection or key, and
carries a TODO noting the connection is configured in the admin panel; the app
sets `WEBUI_SECRET_KEY = "local-only"`.

Per the official OpenWebUI docs, external OpenAI-compatible endpoints are
configured under **Admin Settings → Connections → OpenAI**, and that
configuration is **persistent config stored internally**: once the app has
launched, the corresponding config environment variables are ignored unless
`ENABLE_PERSISTENT_CONFIG=False`. Therefore the endpoint and key are **runtime
DB/admin state** and cannot be migrated by editing Nix. The exact database
filename and table are **not asserted here** (unconfirmed) — back up the whole
state directory instead.

[tier:medium] Back up the entire `/var/lib/open-webui` state directory before any
admin change (service stopped or a consistent snapshot).

[acceptance]
- A restorable backup of `/var/lib/open-webui` exists and its creation timestamp predates the admin connection change.
- The backup is verified as readable/restorable; no key value is printed while taking it.
[/acceptance]

The admin-panel edit itself is a user action — see §12.6, item 2. Rollback:
restore the backup, or re-enter the previous key in the admin panel.

### 12.4 Gateway clients to migrate off direct llama-swap

`modules/nas/litellm/default.nix:43-54` already forwards enabled **local**
models from the gateway to `http://127.0.0.1:8081/v1` using the placeholder key
`sk-none`. The three clients below currently talk to llama-swap directly with a
blank/placeholder key; they should instead talk to `https://ai.homehub.tv/v1`
with the SOPS-derived master key, so auth, routing, and Langfuse tracing are
uniform.

| Client | Current config (confirmed) | Models in use | Target |
| ------ | -------------------------- | ------------- | ------ |
| Karakeep | `modules/nas/karakeep.nix:44-55` — port 8081, blank key | `qwen-3.5-4b`, `qwen3-embedding-0.6b`, local OCR path | `https://ai.homehub.tv/v1` + SOPS-derived master key |
| Paperless-GPT | `modules/nas/paperless-gpt.nix:31-41` — `127.0.0.1:8081`, `localonly` key | `qwen-3.5-4b`, `glm-ocr-f16` | `https://ai.homehub.tv/v1` + SOPS-derived master key |
| Miniflux curator | `modules/nas/content.nix:46-60` — host `http://nas:8081` | `qwen3-embedding-0.6b` | `https://ai.homehub.tv/v1` + SOPS-derived master key |

In all three cases the key must arrive via a SOPS secret path / environment file
— never as a literal in Nix — and the model IDs stay the same.

[tier:medium] Migrate **Karakeep** (`modules/nas/karakeep.nix:44-55`): base URL →
`https://ai.homehub.tv/v1`, key → SOPS-derived master key (env/environmentFile),
model IDs unchanged.

[acceptance]
- Karakeep's configured endpoint is `https://ai.homehub.tv/v1` and its key is read from a SOPS secret path (no literal key in Nix).
- `qwen-3.5-4b` and `qwen3-embedding-0.6b` remain the configured model IDs; the local OCR path is still configured.
- Regression test: bookmark one real item and confirm the generated summary/tags appear, its embedding is stored, and an OCR-bearing item still produces text.
[/acceptance]

[tier:medium] Migrate **Paperless-GPT** (`modules/nas/paperless-gpt.nix:31-41`):
`127.0.0.1:8081` → `https://ai.homehub.tv/v1`, replace the `localonly` key with
the SOPS-derived master key, model IDs unchanged.

[acceptance]
- Paperless-GPT's endpoint is `https://ai.homehub.tv/v1`; the `localonly` placeholder is gone and the key comes from a SOPS secret path.
- `qwen-3.5-4b` and `glm-ocr-f16` remain the configured model IDs.
- Regression test: process one real document on the normal (text) path and one on the vision/OCR path; both complete and write results back to Paperless.
[/acceptance]

[tier:fast] Before editing **Miniflux curator**, verify the exact consuming
module and config key names in `modules/nas/content.nix:46-60` (host/base-URL key,
key/token option, model option). Do not guess them.

[acceptance]
- The exact option/key names that carry the `http://nas:8081` host and the embedding model in `modules/nas/content.nix` are read and recorded verbatim before any edit.
[/acceptance]

[tier:medium] Migrate **Miniflux curator** using the verified names: host
`http://nas:8081` → `https://ai.homehub.tv/v1`, add the SOPS-derived master key,
`qwen3-embedding-0.6b` unchanged.

[acceptance]
- The curator config points at `https://ai.homehub.tv/v1` with a SOPS-sourced key; `qwen3-embedding-0.6b` is unchanged.
- Regression test: a real curator run produces embeddings for at least one newly fetched entry with no auth errors in its log.
[/acceptance]

### 12.5 Intentional direct llama-swap bypasses — preserve unchanged

These reach llama-swap (`:8081`) directly **by design** (local audio and warmup
paths) and are **not** part of the master-key client migration. They must not be
re-pointed at the gateway, and their behavior is guarded by before/after checks:

| Path | Confirmed lines | Why it stays direct |
| ---- | --------------- | ------------------- |
| Hermes STT/TTS | `modules/services/hermes-agent/default.nix:133-149` | local audio endpoints |
| Desktop speech-to-text | `users/cody/desktop/speech-to-text.nix:38-45,195-209` | local audio + warmup path |
| Waybar helper | `users/cody/desktop/waybar.nix:20-27` | local warmup/status helper |

Hermes' main LLM routes go direct to `xai-oauth` / `opencode-go` and are likewise
unaffected by this migration.

[tier:medium] Run an explicit **before** and **after** reachability check on
`:8081` and on the model/audio endpoints these three paths use, and confirm no
configuration change moved them onto LiteLLM.

[acceptance]
- Before and after the §12.4 edits, `:8081` is reachable and the model/audio endpoints used by the three paths above respond identically.
- Hermes STT and TTS still function against `:8081`; desktop speech-to-text still transcribes; the Waybar helper still reports/warms as before.
- A diff of the changed configs shows none of the three bypass paths (or Hermes' `xai-oauth`/`opencode-go` LLM routes) were re-pointed at `https://ai.homehub.tv/v1`.
[/acceptance]

### 12.6 User-owned / manual actions (cannot be done in Nix)

These are Cody's actions, in order. They are not automatable from this repo and
each blocks the corresponding acceptance item in §12.7.

1. [tier:medium] Choose and stand up the OpenCode session secret delivery (per
   the §13 decision #5 mechanism), then restart the OpenCode session.

   [acceptance]
   - A fresh OpenCode session authenticates with the SOPS-sourced `LITELLM_API_KEY`; the old session is gone.
   [/acceptance]

2. [tier:medium] OpenWebUI admin-panel update, **after** the §12.3 state backup
   and **before** cutover completion: log in as admin → Settings → Connections →
   OpenAI → set the endpoint to `https://ai.homehub.tv/v1` and the key to the
   stateless master key. Leave `WEBUI_SECRET_KEY` unchanged. Then test one
   currently intended **hosted** model and one **local** LiteLLM model. Remove
   the old virtual key from the connection only after both succeed.

   [acceptance]
   - The admin OpenAI connection points at `https://ai.homehub.tv/v1` with the master key; `WEBUI_SECRET_KEY` is untouched.
   - One hosted model and one local LiteLLM model each return a completion from the OpenWebUI chat UI.
   - The old virtual key is removed from the connection only after both tests pass; no key value is printed, screenshotted, or copied into this repo.
   - Rollback path confirmed available: restore the `/var/lib/open-webui` backup or re-enter the previous key.
   [/acceptance]

3. [tier:medium] Provide the master key to the §12.4 services via `sops edit` on
   the `nas` host secrets (no literal keys in Nix), then rebuild and restart
   those services.

   [acceptance]
   - The master key is present only in SOPS-encrypted material; `sops edit` + `updatekeys` succeed and the secret paths render.
   - Karakeep, Paperless-GPT, and the Miniflux curator restart cleanly and authenticate to the gateway.
   [/acceptance]

4. [tier:medium] Delete the retired client-side virtual keys — **only** after the
   §12.7 checklist is complete.

   [acceptance]
   - Every retired key is deleted after §12.7 passes; each deletion is recorded against the §12.1 inventory.
   [/acceptance]

5. [tier:heavy] Record the owner decisions this section depends on: accept the
   shared-master-key threat model, the session secret delivery mechanism, and the
   classification of any remaining `:8090`/`:8081` peer (§13 decisions #4–#6).

   [acceptance]
   - All three decisions are recorded before DB retirement (§9 Phase 6) proceeds.
   [/acceptance]

### 12.7 End-to-end dependency acceptance checklist

This is **not** a single automated test. Each item below is a separate operator
check with its own criteria; all must pass before any virtual key is retired and
before the `litellm` DB is dropped (§9 Phase 6, §10).

[tier:medium] **Check 1 — unauthenticated request is rejected.**

[acceptance]
- A request to `https://ai.homehub.tv/v1/models` with no `Authorization` header is rejected (401/403), and the same request with a bogus bearer token is also rejected.
[/acceptance]

[tier:medium] **Check 2 — OpenCode direct models.**

[acceptance]
- With the SOPS-sourced key, an OpenCode request to a `litellm/gpt-5.6-*` model and one to `litellm/hy3` each return a completion.
[/acceptance]

[tier:medium] **Check 3 — OpenCode model-router tiers.**

[acceptance]
- fast → `litellm/gpt-5.6-luna`, medium → `litellm/hy3`, heavy → `litellm/gpt-5.6-terra`: each tier route returns a completion, with the model IDs unchanged.
[/acceptance]

[tier:medium] **Check 4 — OpenWebUI hosted + local.**

[acceptance]
- One hosted model and one local LiteLLM model each return a completion in the OpenWebUI chat UI after the §12.6 item 2 admin change.
[/acceptance]

[tier:medium] **Check 5 — Karakeep.**

[acceptance]
- Summary generation, embedding storage, and the local OCR path each succeed for a real bookmark, with no auth errors in the Karakeep log.
[/acceptance]

[tier:medium] **Check 6 — Paperless-GPT.**

[acceptance]
- One real document completes on the normal text path and one on the vision/OCR path (`glm-ocr-f16`), with results written back to Paperless.
[/acceptance]

[tier:medium] **Check 7 — Miniflux curator embeddings.**

[acceptance]
- A real curator run produces `qwen3-embedding-0.6b` embeddings for at least one new entry, with no auth errors.
[/acceptance]

[tier:medium] **Check 8 — direct llama-swap workflows intact.**

[acceptance]
- Hermes STT/TTS, desktop speech-to-text, and the Waybar helper all still work against `:8081` (matching the §12.5 "before" baseline), and none was re-pointed at the gateway.
[/acceptance]

[tier:medium] **Check 9 — Langfuse traces for gateway clients.**

[acceptance]
- A trace exists in Langfuse for each gateway client exercised in Checks 2–7 (OpenCode, OpenWebUI, Karakeep, Paperless-GPT, Miniflux curator).
[/acceptance]

[tier:fast] **Check 10 — virtual-key inventory is unused.**

[acceptance]
- Re-running the §7 inventory query shows no virtual key in active use (no recent usage attributable to any non-master key), reconciled against the §12.1 record.
- **Gate:** only with Checks 1–10 all passing may the old keys be retired and the `litellm` DB be dropped after the retention window (§9 Phase 6, §10).
[/acceptance]

---

## 13. Explicit decisions needing confirmation

These are **not** resolved by this plan and require an owner decision before or
during execution:

1. [tier:heavy] **Does Codex polling stay?** `enableCodexUsage` is fork-only; upstream has no
   Codex poller. Options: (a) drop Codex usage reporting, (b) reimplement a
   local poller against the OpenCode Go API, (c) keep the fork *only* for this
   feature (rejected — defeats the migration). **Decision needed.**

   [acceptance]
   - An owner decision is recorded selecting (a), (b), or rejecting (c); the chosen option is reflected in the module (or an explicit "drop" is documented).
   [/acceptance]

2. [tier:medium] **Does the proxy-extras / `previous_response_id` response patch matter on
   1.97.0?** Current config sets
   `additional_drop_params = [ "previous_response_id" ]` because the fork's
   LiteLLM didn't handle it. Verify on 1.97.0 whether this is still required; if
   upstream handles `previous_response_id` natively, drop it; otherwise keep the
   drop param (or carry a patch). **Decision needed** (verify against 1.97.0
   behavior).

   [acceptance]
   - Behavior of `previous_response_id` on 1.97.0 is verified; the drop param is kept or dropped accordingly in `settings`.
   [/acceptance]

3. [tier:medium] **Master-key-only is accepted** as the virtual-key replacement (§7). Confirm
   no hidden consumer uses a distinct virtual key (Phase 0 discovery gates this).

   [acceptance]
   - Phase 0 discovery confirms no hidden consumer uses a distinct virtual key; master-key-only is accepted by the owner.
   [/acceptance]

4. [tier:heavy] **Shared-master-key threat model accepted?** After §12, five or
   more distinct consumers hold the same bearer token, so compromise of any one
   consumer implies rotating the key for all of them (§7 limitations). Confirm
   this is accepted, or record the alternative before cutover completes.

   [acceptance]
   - The owner records acceptance of the shared-master-key blast radius (or names the alternative), referencing the §12 consumer list.
   [/acceptance]

5. [tier:heavy] **Which user-session secret delivery mechanism?** How
   `LITELLM_API_KEY` reaches Cody's interactive OpenCode session from SOPS
   (§12.2). No mechanism is assumed by this plan; it must be designed and
   validated before the harness change is switched on.

   [acceptance]
   - One mechanism is selected and recorded with its trust boundary; it keeps the value out of the Nix store, the generated OpenCode config, and git.
   [/acceptance]

6. [tier:heavy] **Classification of remaining `:8090`/`:8081` peers.** Any peer
   from the §12.1 inventory not already classified as a gateway client (§12.4) or
   an intentional direct bypass (§12.5) needs an owner call before key/DB
   retirement.

   [acceptance]
   - Every peer in the §12.1 record is classified as migrate, preserve-direct, or decommission; none remains unknown before §9 Phase 6.
   [/acceptance]

---

## Final plan review

[tier:heavy] Perform a complete read-through review of this plan before execution: confirm the
package/version decision, the upstream-vs-fork boundary (§4), the exact config
changes (§5), the local systemd replacements (§6), the virtual-key decision (§7),
the discovery/acceptance commands (§8), the phased cutover/rollback (§9), the
retention/backup sequencing (§10), the Langfuse privacy note (§11), the downstream
consumer migration with its discovery gate, user-owned actions, and end-to-end
checklist (§12), and the open owner decisions (§13) are internally consistent and
technically unchanged from the agreed plan. No secret values are present; only
SOPS secret names are referenced.

[acceptance]
- Every section (§1–§13) is present and consistent; the upstream-vs-fork boundary and config mappings are unchanged.
- The §12 consumer migration, the §12.1 discovery gate, and the §12.7 checklist gate virtual-key/DB retirement (§9 Phase 6, §10), and the §12.5 direct llama-swap bypasses remain unmigrated.
- All executable steps carry a valid tier tag and every non-trivial step has an acceptance block.
- No raw secret values appear; only SOPS secret names are referenced.
- The phased cutover/rollback and retention sequencing remain coherent and reversible.
[/acceptance]

---

## 14. Appendix — file/path reference

| Path                                            | Change                                |
| ----------------------------------------------- | ------------------------------------- |
| `modules/nas/litellm/default.nix`               | Fork block → upstream `services.litellm` + local units (§5, §6) |
| `modules/nas/litellm/models.nix`                | Unchanged                             |
| `services.postgresql` (ensureDB/User)           | Unchanged (+ local role-password unit) |
| `services.postgresqlBackup` / `zfs-create-backup-litellm` | Unchanged                |
| `services.nginx.virtualHosts` (`ai.homehub.tv`)| Unchanged (port 8090)                 |
| SOPS `litellm-env`                              | Becomes the single combined env secret (§5.3) |
| SOPS `litellm-database-env`                     | Reused for the DB role password / `DATABASE_URL`; **removed at the DB-free cutover (§9 Phase 5)**, before the DB is dropped (§9 Phase 6), not at the transition cutover |
| SOPS `litellm-langfuse-env`, `opencode-go-api-key-env` | Folded into `litellm-env` (§5.3) |
| `stateDir` `/var/lib/litellm`                   | Shared; preserved across switch       |
| `users/cody/harness/opencode/default.nix:72-93` | `litellm` provider gains `options.apiKey = "{env:LITELLM_API_KEY}"`; `npm`/`baseURL`/model list unchanged (§12.2) |
| `users/cody/harness/opencode/tools/model-router/default.nix:16-30` | Unchanged model IDs (`gpt-5.6-luna` / `hy3` / `gpt-5.6-terra`); no auth of its own; per-tier route test (§12.2) |
| `modules/nas/open-webui.nix:9-41`               | Unchanged in Nix; connection/key are runtime admin state (§12.3) |
| `/var/lib/open-webui` (OpenWebUI runtime state) | Persistent config DB holds the OpenAI connection + key; backed up before the admin change, restored on rollback; `WEBUI_SECRET_KEY` unchanged; exact DB filename/table unconfirmed (§12.3) |
| `modules/nas/karakeep.nix:44-55`                | 8081 + blank key → `https://ai.homehub.tv/v1` + SOPS master key; models unchanged (§12.4) |
| `modules/nas/paperless-gpt.nix:31-41`           | `127.0.0.1:8081` + `localonly` → `https://ai.homehub.tv/v1` + SOPS master key; models unchanged (§12.4) |
| `modules/nas/content.nix:46-60` (Miniflux curator) | `http://nas:8081` → `https://ai.homehub.tv/v1` + SOPS master key; option names verified before edit (§12.4) |
| `modules/nas/litellm/default.nix:43-54`         | Unchanged local-model forwarding to `http://127.0.0.1:8081/v1` with `sk-none` (§12.4 context) |
| `modules/services/hermes-agent/default.nix:133-149` | Unchanged — intentional direct llama-swap STT/TTS (§12.5) |
| `users/cody/desktop/speech-to-text.nix:38-45,195-209` | Unchanged — intentional direct llama-swap audio/warmup (§12.5) |
| `users/cody/desktop/waybar.nix:20-27`           | Unchanged — intentional direct llama-swap helper (§12.5) |

**Markdown lint:** no project markdown lint/formatter command was found
(no `.markdownlint*`, `mdformat`, `prettier`, `Makefile`/`justfile` lint target
in repo root), so no formatting pass was run; this document is hand-formatted to
the repo's existing Markdown style.

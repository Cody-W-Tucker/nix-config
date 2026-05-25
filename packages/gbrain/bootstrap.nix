{
  writeShellApplication,
  git,
  gnugrep,
  openssl,
  coreutils,
  gbrainPkg,
}:

writeShellApplication {
  name = "gbrain-bootstrap";
  runtimeInputs = [
    git
    gnugrep
    openssl
    coreutils
    gbrainPkg
  ];
  text = ''
        set -eu

        : "''${GBRAIN_ROOT:?GBRAIN_ROOT is required}"
        : "''${GBRAIN_HOME:?GBRAIN_HOME is required}"

    repo_root="$GBRAIN_ROOT"
    brain_home="$GBRAIN_HOME"
    config_dir="$brain_home/.gbrain"
    config_file="$config_dir/config.json"
        gitignore_file="$repo_root/.gitignore"

        json_escape() {
          local value="$1"
          value=''${value//\\/\\\\}
          value=''${value//\"/\\\"}
          value=''${value//$'\n'/\\n}
          value=''${value//$'\r'/\\r}
          value=''${value//$'\t'/\\t}
          printf '%s' "$value"
        }

        write_postgres_config() {
          local tmp_config
      mkdir -p "$config_dir"
      tmp_config="$config_file.tmp"

          {
            printf '{\n'
            printf '  "engine": "postgres",\n'
            printf '  "database_url": "%s"' "$(json_escape "$GBRAIN_DATABASE_URL")"
            if [ -n "''${GBRAIN_EMBEDDING_MODEL:-}" ]; then
              printf ',\n  "embedding_model": "%s"' "$(json_escape "$GBRAIN_EMBEDDING_MODEL")"
              if [ -n "''${GBRAIN_EMBEDDING_DIMENSIONS:-}" ]; then
                printf ',\n  "embedding_dimensions": %s' "$GBRAIN_EMBEDDING_DIMENSIONS"
              fi
              printf '\n'
            else
              printf ',\n  "embedding_disabled": true\n'
            fi
            printf '}\n'
          } > "$tmp_config"

          chmod 600 "$tmp_config"
          mv "$tmp_config" "$config_file"
        }

    mkdir -p "$brain_home"
    mkdir -p "$config_dir"

        # When state is split from the knowledge repo, bootstrap should not
        # create or mutate the worktree.
        if [ "$repo_root" = "$brain_home" ]; then
          mkdir -p "$repo_root"

          if [ ! -d "$repo_root/.git" ]; then
            git -C "$repo_root" init -q
          fi

          if [ -e "$gitignore_file" ]; then
            if ! grep -qxF ".gbrain/" "$gitignore_file"; then
              printf '\n.gbrain/\n' >> "$gitignore_file"
            fi
          else
            printf '.gbrain/\n' > "$gitignore_file"
          fi
        fi

        if [ -n "''${GBRAIN_DATABASE_URL:-}" ]; then
          : "''${GBRAIN_MCP_ENV_FILE:?GBRAIN_MCP_ENV_FILE is required with GBRAIN_DATABASE_URL}"
          : "''${GBRAIN_MCP_TOKEN_NAME:?GBRAIN_MCP_TOKEN_NAME is required with GBRAIN_DATABASE_URL}"
          : "''${GBRAIN_PSQL_BIN:?GBRAIN_PSQL_BIN is required with GBRAIN_DATABASE_URL}"

      token_file="$config_dir/mcp-token"
          env_file="$GBRAIN_MCP_ENV_FILE"

          mkdir -p "$(dirname "$env_file")"

          if [ ! -e "$token_file" ]; then
            openssl rand -hex 32 > "$token_file"
            chmod 600 "$token_file"
          fi

          token="$(tr -d '\n' < "$token_file")"
          {
            printf 'GBRAIN_MCP_TOKEN=%s\n' "$token"
            printf 'PGHOST=/run/postgresql\n'
          } > "$env_file"
          chmod 600 "$env_file"

          if [ -e "$config_file" ] && grep -Eq '"engine"[[:space:]]*:[[:space:]]*"pglite"' "$config_file"; then
        backup_dir="$brain_home/.gbrain.pglite-backup"
        if [ ! -e "$backup_dir" ]; then
          mv "$config_dir" "$backup_dir"
          mkdir -p "$config_dir"
        fi
      fi

          if [ ! -e "$config_file" ]; then
            write_postgres_config
          fi

          GBRAIN_HOME="$brain_home" gbrain config set search.mode "''${GBRAIN_SEARCH_MODE:-conservative}"

          token_hash="$(printf '%s' "$token" | sha256sum | cut -d' ' -f1)"
          "$GBRAIN_PSQL_BIN" "$GBRAIN_DATABASE_URL" <<SQL
    DELETE FROM access_tokens WHERE name = '$GBRAIN_MCP_TOKEN_NAME';
    INSERT INTO access_tokens (name, token_hash, permissions)
    VALUES ('$GBRAIN_MCP_TOKEN_NAME', '$token_hash', '{"takes_holders":["world"]}'::jsonb);
    SQL
        else
          if [ ! -e "$config_file" ]; then
            if [ -n "''${GBRAIN_EMBEDDING_MODEL:-}" ]; then
              set -- gbrain init --pglite --embedding-model "$GBRAIN_EMBEDDING_MODEL"
              if [ -n "''${GBRAIN_EMBEDDING_DIMENSIONS:-}" ]; then
                set -- "$@" --embedding-dimensions "$GBRAIN_EMBEDDING_DIMENSIONS"
              fi
              LLAMA_SERVER_BASE_URL="''${LLAMA_SERVER_BASE_URL:-}" GBRAIN_HOME="$brain_home" "$@"
            else
              GBRAIN_HOME="$brain_home" gbrain init --pglite --no-embedding
            fi

            GBRAIN_HOME="$brain_home" gbrain config set search.mode "''${GBRAIN_SEARCH_MODE:-conservative}"
          elif [ -n "''${GBRAIN_EMBEDDING_MODEL:-}" ] \
            && ! grep -Fq "\"embedding_model\": \"$GBRAIN_EMBEDDING_MODEL\"" "$config_file"; then
            set -- gbrain reinit-pglite --yes --embedding-model "$GBRAIN_EMBEDDING_MODEL"
            if [ -n "''${GBRAIN_EMBEDDING_DIMENSIONS:-}" ]; then
              set -- "$@" --embedding-dimensions "$GBRAIN_EMBEDDING_DIMENSIONS"
            fi
            LLAMA_SERVER_BASE_URL="''${LLAMA_SERVER_BASE_URL:-}" GBRAIN_HOME="$brain_home" "$@"

            GBRAIN_HOME="$brain_home" gbrain config set search.mode "''${GBRAIN_SEARCH_MODE:-conservative}"
          fi
        fi
  '';
}

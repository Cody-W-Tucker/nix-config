---
name: grafana-tracing-workflows
description: Use Grafana, Loki, Tempo, and OpenTelemetry traces in this repo to explain NixOS rebuild outcomes and cross-check system health.
---

# Grafana Tracing Workflows

Use this skill when working on the CodyOS observability loop.

## Repo-specific context

- The monitoring stack lives in `modules/server/monitoring.nix`
- Discover live Grafana datasource UIDs before querying; Grafana may still have legacy datasource IDs in its database
- `Tempo` listens on HTTP `3200`; `OpenTelemetry Collector` receives OTLP on `4317` and `4318`
- `update` emits a root trace named `nixos.rebuild`
- `pull-update` emits a root trace named `nixos.pull_update`
- Both scripts use OpenTelemetry service name `codyos-update`
- Post-switch spans include failed unit counts and recent journal error deltas

## What to use for what

- Use `Tempo` when the question is about sequence, duration, or change attribution
- Use `Loki` when the question is about specific service errors or rebuild logs
- Use `Prometheus` when the question is about health trends or current host state

## Default investigation flow

1. Confirm the monitoring stack is healthy on `server`
   - If Grafana MCP calls return `502`, inspect `grafana.service`, `tempo.service`, and `opentelemetry-collector.service` over SSH first
2. Check traces in `Tempo`
   - Filter by service name `codyos-update`
   - Look for root spans `nixos.rebuild` and `nixos.pull_update`
3. Read child spans to find where time or failure happened
   - `nix.format`
   - `nix.check_imports`
   - `git.stage`
   - `git.commit`
   - `git.pull`
   - `nixos.switch`
4. Cross-check health spans
   - `system.health.baseline`
   - `nixos.switch.health`
5. Cross-check logs in `Loki`
   - `unit="nixos-rebuild-switch-to-configuration.service"`
   - `unit="grafana.service"`
   - `unit="tempo.service"`
   - `unit="opentelemetry-collector.service"`
6. Cross-check metrics in `Prometheus`
   - `up`
   - `node_systemd_unit_state{state="failed"}`

## Questions this should answer

- Which change happened?
- Was it a local `update` or a pulled `pull-update`?
- Which step slowed down or failed?
- Did failed units increase after switch?
- Did recent error logs increase after switch?
- Which service logs explain the regression?

## Practical Grafana MCP usage

- Use datasource discovery only after Grafana is healthy
- Prefer `grafana_query_loki_logs` for rebuild and service logs
- Prefer `grafana_query_prometheus` for host health and failed-unit metrics
- Use dashboard creation only after Grafana provisioning is stable

## Common pitfalls

- New repo files must be git-tracked or flakes will not see them
- A `502` from Grafana MCP often means Grafana itself is down, not that the query is wrong
- `Tempo` startup failures may be simple port conflicts; inspect the journal first
- Fixing tracing without checking `Loki` usually hides the actual reason a rebuild degraded health

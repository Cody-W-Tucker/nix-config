# Observability

Shared logging (`logging.nix`, every host) and the NAS-side monitoring stack (`monitoring.nix`, `uptime-kuma.nix`; `den.aspects.monitoring` and `den.aspects.uptime-kuma`, included by nas).

## Monitoring

`monitoring.nix` owns the LGTM-style stack:

- Prometheus for metrics.
- Grafana at `monitoring.homehub.tv` for dashboards.
- Loki for logs, including Nginx log ingestion.
- Tempo for traces and OTLP ingestion.
- Exporters for Nginx, SMART, GPU, and remote targets as configured.

The shared `logging` aspect configures the node and SMART exporters and the journal input. Journal forwarding is opt-in: NAS's `monitoring` aspect includes `logging.forward-local`; Beast selects `logging.forward-to-nas`. The monitoring aspect adds the NAS-specific Nginx access log route. The remote sender and NAS listener use `_loki-endpoint.nix` for the Loki port.

Prometheus scrapes the server and selected `beast` metrics. Important endpoints and roles:

| Component | Endpoint / port | Role |
| --- | --- | --- |
| Grafana | `3001` | Dashboard UI behind `monitoring.homehub.tv` |
| Prometheus | `9001` | Metrics store and scrape scheduler |
| Server node exporter | `9002` | Server host and systemd metrics |
| Server Nginx exporter | `9115` | Nginx status metrics from the local stub status endpoint |
| Server nginxlog exporter | `9117` | Nginx access-log metrics |
| Loki | `3090` | Log storage and query backend |
| Tempo | `3200` | Trace storage and query backend |
| Tempo OTLP gRPC | `127.0.0.1:4327` | Trace ingest |
| Tempo OTLP HTTP | `127.0.0.1:4328` | Trace ingest |
| Beast node exporter | `beast:9002` | Remote host metrics |
| Beast Nvidia GPU exporter | `beast:9835` | GPU metrics for AI workloads |
| SMART exporters | host-specific | Drive health metrics |

Loki is configured as a single-binary filesystem-backed deployment with short retention. Nginx access logs are routed explicitly so both log and metric ingestion stay predictable.

If adding a service, add the exporter and scrape target in the same module that owns the monitoring integration, then expose it in Grafana only when it is useful to operate.


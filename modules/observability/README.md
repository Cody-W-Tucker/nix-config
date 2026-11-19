# Observability

Shared logging (`logging.nix`, every host), the NAS-side monitoring stack (`monitoring.nix`, `uptime-kuma.nix`; `den.aspects.monitoring` and `den.aspects.uptime-kuma`, included by nas) and the egress audit (`egress-audit.nix`; see [Egress audit](#egress-audit)).

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

Grafana has provisioned `Prometheus`, `Tempo` and `Loki` (uid `loki`) datasources.

## Egress audit

`egress-audit.nix` records outbound activity in Loki as `{job="egress"}`, kept for 30 days (other streams keep the 120h default):

| Aspect | Hosts | What it adds |
| --- | --- | --- |
| `egress-audit` | nas, beast | nftables table `inet egress-audit` logs each new connection to a non-private address: `egress-out:` for the host (with UID), `egress-fwd:` for forwarded/Docker traffic. Rate-limited to 50/s per rule. On the NAS, Unbound's own upstream lookups are skipped because its client queries are logged instead. |
| `egress-audit.opensnitch` | beast | OpenSnitch in log-only mode (default allow, no prompts): each connection with the program path, command line, PID and the hostname it resolved. |
| `egress-audit.server` | nas | Loki 30-day retention for the stream and three Grafana alert rules (folder "Egress audit"): new destination country per host vs. the previous 30 days, nft connections on non-routine ports, and a 3x connection spike vs. the 7-day average. |

Unbound query logging itself (`log-queries`, `log-local-actions`) lives in the `dns` aspect. Fluent Bit parses all of it with `_egress-parse.lua`, moves it from the journal stream to the `egress` tag, and adds `country`/`country_name` from the DB-IP country-lite database. Labels are `host`, `source` (`nft`, `opensnitch`, `dns`) and `country`; the remaining fields are JSON, for example:

```logql
{job="egress", source="opensnitch"} | json | path=~".*/curl"
{job="egress", country="RU"}
{job="egress", source="dns"} | json | action="always_nxdomain"
```

The alert rules route to the `Discord` contact point, which is created in the Grafana UI. If you rename it, update `receiver` in `egress-audit.nix`, or Grafana will reject the rules. Each rule groups notifications by its own labels (host + country, host + port, host), so every Discord message names one finding. The unusual-port rule also ignores Tailscale peer traffic, which is sent from source port 41641.

There is no egress dashboard. To browse the stream, use Grafana's Logs Drilldown (`service_name=egress`), which breaks it down by label and JSON field (`country`, `dst`, `dport`, `path`, `qname`, ...).

Limits: services confined to the WireGuard namespace show up only as traffic to the VPN endpoint, and anyone with root on a host can turn off its logging.

`logging.desktop` and `nvidia` advertise endpoints through Den's `prometheus-targets` pipe on hosts that select them. `monitoring.nix` collects those endpoints from same-system peers and owns the scrape jobs. No target is advertised merely because a host exists. Keep new exporter definitions and their advertisements together; Grafana still owns dashboard presentation.

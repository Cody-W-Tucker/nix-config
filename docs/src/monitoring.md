# Monitoring and logs

Grafana on the NAS shows metrics, logs and outbound connections of both hosts in one place. Nothing sends alerts; problems show on the dashboards only.

## Dashboards

| URL | Shows |
| --- | --- |
| [monitoring.homehub.tv](https://monitoring.homehub.tv) | Grafana: metrics (Prometheus), logs and egress records (Loki), traces (Tempo). Dashboards are edited in Grafana. |
| [uptime.homehub.tv](https://uptime.homehub.tv) | Uptime Kuma. Monitors are edited in its UI. |

Backup panels stay empty while the NAS backup disk is unmounted.

## Logs

Both hosts' journals are in Loki for the last 5 days, so beast's journal can be read from the NAS.

| Loki selector | Contents |
| --- | --- |
| `{job="systemd-journal", host="beast"}` | beast journal (also `host="nas"`; labels `unit`, `level`) |
| `{job="nginx-access", host="nas"}` | nginx access log |

## Outbound connections

`{job="egress"}` holds 30 days of every new connection from either host to a non-local address, and every DNS query to the NAS. OpenSnitch records the program, command line and PID; it never prompts or blocks. Traffic inside the LAN or Tailscale is not recorded. The VPN-confined media apps appear only as traffic to the VPN endpoint.

| `source` | Records |
| --- | --- |
| `opensnitch` | Programs on either host |
| `nft` | Forwarded and container traffic |
| `dns` | Unbound queries and blocks |

Every record has a `country` label.

## Changing it

All in [`modules/observability/`](../../modules/observability):

| To change | Edit |
| --- | --- |
| Grafana, Prometheus, Loki, retention | [`monitoring.nix`](../../modules/observability/monitoring.nix) |
| Which hosts forward logs | [`logging.nix`](../../modules/observability/logging.nix) |
| Egress recording | [`egress-audit.nix`](../../modules/observability/egress-audit.nix) |
| Uptime Kuma | [`uptime-kuma.nix`](../../modules/observability/uptime-kuma.nix) |

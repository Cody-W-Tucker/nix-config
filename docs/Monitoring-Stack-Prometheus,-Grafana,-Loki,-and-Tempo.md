# Monitoring Stack: Prometheus, Grafana, Loki, and Tempo

Monitoring implementation is owned by [`modules/server/monitoring.nix`](../modules/server/monitoring.nix) and documented in [`modules/server/README.md`](../modules/server/README.md#monitoring).

Use the local README for the current operator view of:

- Prometheus scrape ownership
- Grafana exposure at `monitoring.homehub.tv`
- Loki log ingestion
- Tempo and OTLP trace ingestion
- Exporters and remote targets

This central page stays short so monitoring details remain beside the Nix module that changes them.

# cluster-monitoring

Monitoring für meinen k3s-Single-Node-Cluster – komplett als Code und per
**Argo CD (GitOps)** deployt: Metriken, Logs, Dashboards und Alerting.

## Stack

- **kube-prometheus-stack** – Prometheus, Alertmanager, Grafana, node-exporter
- **Loki + Alloy** – Log-Sammlung (IP-/Suchbegriff-Scrubbing, 14 Tage Aufbewahrung)
- **Argo CD** – GitOps: Änderung committen → `git push` → wird automatisch deployt

Grafana läuft unter `https://grafana.adrianrostin.de` (TLS via cert-manager,
Login nur über GitHub). Traefik-Zugriffslogs werden gar nicht gesammelt, in den
übrigen Logs vor dem Speichern IP-Adressen und Suchbegriffe entfernt.

GitOps-Setup (Argo CD) im Detail: [argocd/README.md](argocd/README.md)

## Lizenz

[MIT](LICENSE)

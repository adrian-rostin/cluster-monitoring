#!/usr/bin/env bash
# Installiert / aktualisiert den Monitoring-Stack im Namespace 'monitoring'.
# Idempotent: mehrfaches Ausführen ist unschädlich.
#
#   ./install.sh            # alles
#   ./install.sh secrets    # nur Secrets prüfen/anlegen
#   ./install.sh charts     # nur Helm-Charts
#   ./install.sh manifests  # nur kubectl-Manifeste
#
# Secrets werden NIE ins Repo geschrieben. Das Skript gibt Secret-Werte nicht aus.
set -euo pipefail

NS="monitoring"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Chart-Versionen (November 2026, gepinnt)
KPS_VERSION="93.3.1"
LOKI_VERSION="21.3.1"
ALLOY_VERSION="1.16.0"

msg() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }

require() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 1; }; }
require kubectl
require helm

ensure_namespace() {
  if ! kubectl get ns "$NS" >/dev/null 2>&1; then
    msg "Namespace $NS anlegen"
    kubectl create ns "$NS"
  fi
  # node-exporter braucht hostNetwork/hostPID/hostPath -> Pod Security 'privileged'.
  # ACHTUNG: ändert ein Label am bestehenden Namespace. Bewusst gesetzt.
  msg "Pod-Security auf 'privileged' setzen (für node-exporter)"
  kubectl label ns "$NS" \
    pod-security.kubernetes.io/enforce=privileged \
    pod-security.kubernetes.io/audit=privileged \
    pod-security.kubernetes.io/warn=privileged \
    --overwrite
}

ensure_secrets() {
  msg "Secret 'grafana-admin' (Notfall-Admin) prüfen"
  if ! kubectl -n "$NS" get secret grafana-admin >/dev/null 2>&1; then
    local pw
    pw="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
    kubectl -n "$NS" create secret generic grafana-admin \
      --from-literal=admin-user=admin \
      --from-literal=admin-password="$pw"
    warn "grafana-admin wurde mit zufälligem Passwort angelegt."
    warn "Auslesen bei Bedarf: kubectl -n $NS get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d"
  else
    echo "grafana-admin existiert bereits – unverändert."
  fi

  msg "Secret 'grafana-github-oauth' (GitHub-OAuth) prüfen"
  if ! kubectl -n "$NS" get secret grafana-github-oauth >/dev/null 2>&1; then
    echo "GitHub-OAuth-App-Zugangsdaten eingeben (werden nicht angezeigt/geloggt):"
    local cid csecret
    read -rp "  Client ID: " cid
    read -rsp "  Client Secret: " csecret; echo
    kubectl -n "$NS" create secret generic grafana-github-oauth \
      --from-literal=GF_AUTH_GITHUB_CLIENT_ID="$cid" \
      --from-literal=GF_AUTH_GITHUB_CLIENT_SECRET="$csecret"
    unset cid csecret
  else
    echo "grafana-github-oauth existiert bereits – unverändert."
  fi
}

add_repos() {
  msg "Helm-Repos hinzufügen/aktualisieren"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
  # Loki-OSS-Chart ist nach grafana-community umgezogen (nicht mehr grafana/loki)
  helm repo add grafana-community https://grafana-community.github.io/helm-charts >/dev/null
  helm repo update >/dev/null
}

install_charts() {
  add_repos
  msg "kube-prometheus-stack ($KPS_VERSION)"
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --version "$KPS_VERSION" -n "$NS" \
    -f "$HERE/values/kube-prometheus-stack.yaml" --wait --timeout 10m

  msg "Loki ($LOKI_VERSION)"
  helm upgrade --install loki grafana-community/loki \
    --version "$LOKI_VERSION" -n "$NS" \
    -f "$HERE/values/loki.yaml" --wait --timeout 10m

  msg "Alloy ($ALLOY_VERSION)"
  helm upgrade --install alloy grafana/alloy \
    --version "$ALLOY_VERSION" -n "$NS" \
    -f "$HERE/values/alloy.yaml" --wait --timeout 10m
}

apply_manifests() {
  # Braucht die CRDs aus kube-prometheus-stack (PodMonitor/PrometheusRule).
  msg "Manifeste anwenden (PodMonitor, PrometheusRule, Dashboard)"
  kubectl apply -f "$HERE/manifests/altsetter-podmonitor.yaml"
  kubectl apply -f "$HERE/manifests/altsetter-prometheusrule.yaml"
  kubectl apply -f "$HERE/manifests/dashboards/altsetter-api.yaml"
  msg "Zusätzliche NetworkPolicy im Namespace altsetter (erlaubt Prometheus-Scrape)"
  kubectl apply -f "$HERE/manifests/altsetter-networkpolicy-allow-prometheus.yaml"
}

case "${1:-all}" in
  secrets)   ensure_namespace; ensure_secrets ;;
  charts)    ensure_namespace; install_charts ;;
  manifests) apply_manifests ;;
  all)       ensure_namespace; ensure_secrets; install_charts; apply_manifests ;;
  *) echo "Unbekannt: $1 (erlaubt: all|secrets|charts|manifests)"; exit 1 ;;
esac

msg "Fertig. Status: kubectl get pods -n $NS"

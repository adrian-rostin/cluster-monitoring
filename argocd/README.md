# Argo CD (aktiv)

Das Monitoring wird von **Argo CD** aus diesem Repo verwaltet (GitOps).

## Aufbau

- **Argo CD** v3.6.1 im Namespace `argocd` (installiert aus dem offiziellen
  `install.yaml` dieser Version).
- **Repo-Zugang:** privates Repo `git@github.com:adrian-rostin/cluster-monitoring.git`
  über einen **read-only Deploy-Key** (SSH). In Argo als Secret
  `repo-cluster-monitoring` (Label `argocd.argoproj.io/secret-type: repository`).
  Der private Schlüssel liegt **nicht** im Repo.
- **AppProject** `monitoring` (`project.yaml`): erlaubt dieses Repo + die drei
  Helm-Repos als Quellen und die Ziel-Namespaces `monitoring`, `altsetter`,
  `kube-system` (Letzteres für den coredns-Exporter-Service des kps).
- **Applications** (alle `automated` mit `prune` + `selfHeal`, `ServerSideApply`):
  - `application-kube-prometheus-stack.yaml`
  - `application-loki.yaml`
  - `application-alloy.yaml`
  - `application-manifests.yaml` (PodMonitor, PrometheusRule, Dashboard, NetworkPolicy)

Die Helm-Applications nutzen Multi-Source: Chart aus dem jeweiligen Helm-Repo,
Values-Datei aus diesem Git-Repo (`$values/...`).

## Täglicher Betrieb

Änderungen laufen über Git:

```bash
# Values/Manifeste bearbeiten, dann:
git add -A && git commit -m "..." && git push
# Argo zieht die Änderung automatisch nach (oder sofort erzwingen):
kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
```

Status ansehen:

```bash
kubectl -n argocd get applications
```

Argo-UI (kein Ingress, nur intern):

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# https://localhost:8080  (User: admin)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Secrets

`grafana-admin` und `grafana-github-oauth` liegen **nicht** im Git und werden von
Argo **nicht** verwaltet. Sie wurden per `install.sh secrets` direkt im Cluster
angelegt; Argo fasst bestehende Secrets nicht an.

## Wiederherstellung (Deploy-Key neu)

Falls der Deploy-Key neu erzeugt werden muss:

```bash
ssh-keygen -t ed25519 -f ./deploykey -N "" -C "argocd-cluster-monitoring"
gh repo deploy-key add ./deploykey.pub --repo adrian-rostin/cluster-monitoring --title argocd-readonly
kubectl -n argocd create secret generic repo-cluster-monitoring \
  --from-literal=type=git \
  --from-literal=url=git@github.com:adrian-rostin/cluster-monitoring.git \
  --from-file=sshPrivateKey=./deploykey
kubectl -n argocd label secret repo-cluster-monitoring argocd.argoproj.io/secret-type=repository --overwrite
rm -f ./deploykey ./deploykey.pub
```

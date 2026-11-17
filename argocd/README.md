# Argo CD (vorbereitet – noch NICHT angewendet)

Diese Manifeste sind der spätere GitOps-Schritt. Sie werden **jetzt nicht**
angewendet. Reihenfolge der Übernahme (siehe Haupt-README → „Nächste Schritte"):

1. Repo auf GitHub pushen (`https://github.com/adrian-rostin/cluster-monitoring`).
2. In allen `application-*.yaml` die `repoURL` auf das echte Repo setzen
   (hier als Platzhalter eingetragen) und `targetRevision` (Branch) prüfen.
3. Secrets-Strategie klären: `grafana-admin` und `grafana-github-oauth` dürfen
   **nicht** ins Git. Entweder vorher per `install.sh secrets` anlegen (Argo
   fasst bestehende Secrets nicht an) oder Sealed Secrets / External Secrets.
4. Argo CD im Namespace `argocd` installieren.
5. `kubectl apply -f argocd/project.yaml` und dann die `application-*.yaml`.

Die Helm-Applications nutzen Multi-Source: Chart aus dem jeweiligen Helm-Repo,
Values-Datei aus diesem Git-Repo (`$values/...`).

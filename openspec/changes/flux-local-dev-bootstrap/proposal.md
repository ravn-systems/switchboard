## Why

Local development currently requires manual `kubectl apply` steps with no GitOps enforcement, and the existing Flux config lives alongside base app manifests rather than in a proper cluster-scoped layout. This change establishes a clean FluxCD operator bootstrap for kind, making it trivial to tear down and fully recreate the local cluster with a single task.

## What Changes

- Split Flux config out of `infra/k8s/base/flux/` into a new `infra/clusters/local/` directory structure scoped to the kind cluster
- Define a proper `clusters/local/` entry point that Flux watches, with separate Kustomizations for infrastructure layers
- Update the Taskfile with a `bootstrap` task (and helpers) that: creates the kind cluster, installs the Flux operator, applies the cluster bootstrap config, and waits for Flux to reconcile and deploy all infra
- Remove `kustomize-apply` as the primary workflow in favor of GitOps-driven reconciliation
- Introduce SOPS (with the developer's pre-existing GPG key) for encrypting secrets committed to the repo; Flux's kustomize-controller decrypts them automatically at apply time

## Capabilities

### New Capabilities
- `cluster-bootstrap`: One-command local cluster setup — kind create → flux operator install → flux bootstrap → full infra reconciliation
- `flux-cluster-layout`: Canonical `clusters/local/` directory structure that Flux uses as its sync root, composing infra kustomizations in dependency order
- `sops-secret-management`: SOPS + GPG encryption for secrets committed to the repo; bootstrap exports the developer's pre-existing GPG private key into the cluster so Flux can decrypt secrets automatically

### Modified Capabilities

## Impact

- `Taskfile.yml`: new `bootstrap`, `flux-install`, `flux-bootstrap` tasks; existing `cluster-up` becomes a subtask
- `infra/k8s/base/flux/`: contents moved/reorganized into `infra/clusters/local/`
- `infra/k8s/overlays/local/`: unchanged — still the target of the Flux Kustomization that deploys app workloads
- Depends on: `kind`, `kubectl`, `flux` CLI, `sops`, `gpg` (developer's existing GPG key)
- Adds `infra/clusters/local/.sops.yaml` creation rule referencing the GPG fingerprint
- GPG private key exported from local keyring (not committed), loaded into cluster as `flux-system/sops-gpg` Secret during bootstrap
- `SOPS_GPG_FINGERPRINT` env var must be set by the developer
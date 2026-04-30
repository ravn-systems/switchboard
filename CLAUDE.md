# switchboard

Local development for a kind-based Kubernetes cluster running OSS infrastructure (PostgreSQL, Keycloak, Grafana) managed by FluxCD.

## Prerequisites

- [`kind`](https://kind.sigs.k8s.io/) — local Kubernetes cluster
- `kubectl`
- [`task`](https://taskfile.dev/) — task runner
- [`flux`](https://fluxcd.io/flux/installation/) CLI
- `sops` — secret encryption (`brew install sops`)
- `gpg` — GPG keyring for SOPS encryption

## Quick Start

```bash
task bootstrap
```

This creates the kind cluster, installs the Flux operator, provisions the SOPS decryption key, and applies the cluster config. Flux then reconciles all infrastructure from git.

## Secret Management

Secrets are encrypted with SOPS using GPG before being committed. The GPG fingerprint is `2D71AD789FF4BC5F770D7A49D1A3CF2C2DCA6B61`.

Convention: unencrypted files are named `*secret*.yaml` (gitignored), encrypted files use the `.enc.yaml` suffix and are committed.

To encrypt a new secret:
```bash
sops --encrypt infra/path/to/my-secret.yaml > infra/path/to/my-secret.enc.yaml
```

The `task sops-provision` step (run automatically by `bootstrap`) loads the GPG private key into the cluster so Flux can decrypt secrets at reconcile time.

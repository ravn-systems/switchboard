## Context

The switchboard project deploys OSS infrastructure (PostgreSQL, Keycloak, Grafana) into a local kind cluster. Currently:
- `infra/k8s/base/flux/` holds the FluxInstance and a single Kustomization pointing at `infra/k8s/overlays/local`
- The Flux config lives alongside app base manifests, not in a cluster-scoped location
- Bootstrapping requires manually running `kind create cluster`, then separately applying flux manifests, waiting for CRDs, then applying the GitRepository/Kustomization — there is no single command to bring everything up
- The Flux operator is used (not the standard `flux bootstrap` CLI) via `FluxInstance` CRD

## Goals / Non-Goals

**Goals:**
- Single `task bootstrap` command to go from zero to a fully running kind cluster with all infra reconciling
- Clean `infra/clusters/local/` directory that is the sole Flux sync root
- Dependency-ordered Kustomizations (flux-system → namespaces → infra workloads)
- Taskfile tasks that are composable (bootstrap = cluster-up + flux-install + flux-bootstrap)
- Local-only scope: no changes to CI, no GitHub token/PAT setup

**Non-Goals:**
- Multi-cluster support or staging/prod environments
- Flux image automation or alerting setup
- Helm chart for the Flux operator itself (using raw manifests is fine for local)
- GitHub token/SSH key for private repo auth (repo is public or we handle separately)

## Decisions

### D1: clusters/local/ as Flux sync root (not infra/k8s/base/flux/)

The `clusters/local/` directory becomes the path Flux watches in the GitRepository. It contains only cluster-level orchestration: the FluxInstance and Kustomization objects that reference infra layers. App manifests stay in `infra/k8s/`.

**Rationale:** Standard Flux monorepo pattern. Separating cluster config from app manifests makes it clear what Flux uses as its entrypoint vs. what it deploys. Avoids the current confusion where `infra/k8s/base/flux/` is both a base manifest and the sync root.

**Alternative considered:** Keep everything in `infra/k8s/base/flux/` and just fix the Taskfile. Rejected because the sync path would still mix operator config with app base, and scaling to more clusters would require duplication.

### D2: Flux Operator install via kubectl + GitHub release manifest

Install the Flux operator CRDs and controller using:
```
kubectl apply -f https://github.com/controlplane.io/flux-operator/releases/latest/download/install.yaml
```
Then apply the `FluxInstance` from `clusters/local/flux-instance.yaml`.

**Rationale:** Avoids needing helm for the operator itself. The operator manifest is stable and idempotent. Using `kubectl apply --server-side` handles field ownership correctly.

**Alternative considered:** Helm install of flux-operator. More setup, not needed for local dev.

### D3: Two-phase bootstrap in Taskfile

Phase 1 — Cluster + operator: `cluster-up` → `flux-operator-install` → apply `clusters/local/`
Phase 2 — Flux reconciles everything else automatically from git

The Taskfile `bootstrap` task chains these with `task` dependencies and uses `kubectl wait` to gate phase 2 on phase 1 completing.

**Rationale:** Makes each step independently re-runnable and debuggable. A developer can run `task flux-operator-install` alone if the cluster already exists.

### D4: SOPS + GPG for secret encryption

Secrets (e.g., GitHub App credentials, database passwords) are encrypted with SOPS using the developer's pre-existing GPG key before being committed. The GPG private key is exported from the local keyring and loaded into the cluster as a Kubernetes Secret in `flux-system` during bootstrap. Flux's kustomize-controller then uses this key to decrypt secrets at reconcile time.

**Workflow:**
1. Developer identifies their GPG key fingerprint: `gpg --list-secret-keys --keyid-format LONG`
2. The fingerprint is placed in `infra/clusters/local/.sops.yaml` as a creation rule (pgp field)
3. `task sops-provision` exports the GPG private key (`gpg --export-secret-keys --armor <fingerprint>`) and creates `flux-system/sops-gpg` Secret with the armored key in `sops.asc`
4. The Flux Kustomization references `.spec.decryption.provider: sops` and `.spec.decryption.secretRef.name: sops-gpg`
5. Developers encrypt secrets with `sops --encrypt` before committing; SOPS uses the GPG key from `.sops.yaml`
6. `SOPS_GPG_FINGERPRINT` Taskfile var (or `.envrc`) stores the fingerprint so tasks can reference it

**Rationale:** Developer already has a GPG key — no new key material to manage. GPG is well-supported by SOPS and Flux natively. Keeping the private key export out of the repo is the standard security posture.

**Alternative considered:** age keypair. Lighter setup for greenfield, but requires generating and managing a new key when the developer already has GPG. Using the existing GPG key avoids key proliferation.

### D5: Kustomization dependency ordering via dependsOn

The `clusters/local/` kustomization.yaml composes:
1. `flux-instance.yaml` — the FluxInstance (installs Flux components)
2. `infra.yaml` — a Flux Kustomization pointing at `infra/k8s/overlays/local` with `dependsOn: [flux-instance]`

Flux's `dependsOn` ensures infra workloads only reconcile after Flux itself is healthy.

**Rationale:** Prevents race conditions where Keycloak Operator CRDs don't exist yet when the Keycloak resource is applied.

## Risks / Trade-offs

- [Flux operator version drift] The `latest` tag in the install URL may break. → Pin to a specific release version (e.g., `v0.x.y`) in the Taskfile var.
- [kind cluster already exists] `kind create cluster` fails if cluster exists. → Add a check or use `kind create cluster ... || true` with a note, or a separate `cluster-reset` task.
- [Flux reconciles from git, not local] After bootstrap, changes must be pushed to the repo to take effect — can't just `kubectl apply` locally. → Document this clearly; keep `kustomize-template` task for local preview.
- [Public repo assumption] The GitRepository references `https://github.com/ravn-systems/switchboard.git` without a secret. This works only if the repo is public. → Note this in task output; leave secret scaffolding as a follow-up.
- [GPG key not in keyring] If the developer's GPG key is missing or expired, `sops-provision` fails silently or with a cryptic gnupg error. → Task should verify the key fingerprint exists in the local keyring before exporting.
- [SOPS key not provisioned] If `task sops-provision` is not run, Flux will fail to decrypt secrets. → Make `sops-provision` a dependency of `bootstrap`; emit a clear error referencing the GPG fingerprint env var.
- [Fingerprint not set] `SOPS_GPG_FINGERPRINT` must be set for tasks that reference the GPG key. → Task should fail fast with a helpful message if the var is unset.

## Open Questions

- Should `task bootstrap` be idempotent (safe to re-run on an existing cluster), or should it always tear down and recreate? Recommend: make it idempotent; add `task reset` for full teardown+recreate.
- Pin flux-operator to a specific version or track latest? Recommend: use a Taskfile var `FLUX_OPERATOR_VERSION` defaulting to a known-good version.
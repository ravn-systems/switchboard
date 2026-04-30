## 1. Restructure Flux Directory Layout

- [x] 1.1 Create `infra/clusters/local/` directory
- [x] 1.2 Move `infra/k8s/base/flux/flux.yaml` (FluxInstance) to `infra/clusters/local/flux-instance.yaml` — update `sync.path` to point at `infra/clusters/local`
- [x] 1.3 Create `infra/clusters/local/infra-kustomization.yaml` — Flux Kustomization pointing at `infra/k8s/overlays/local` with `dependsOn: [flux-instance]` and `decryption.provider: sops` + `decryption.secretRef.name: sops-gpg`
- [x] 1.4 Create `infra/clusters/local/kustomization.yaml` composing `flux-instance.yaml` and `infra-kustomization.yaml`
- [x] 1.5 Remove `infra/k8s/base/flux/` directory and remove the `flux` entry from `infra/k8s/base/kustomization.yaml`

## 2. SOPS + GPG Configuration

- [x] 2.1 Create `.sops.yaml` at repo root with a creation rule for `infra/.*secret.*\.yaml` using `pgp: 2D71AD789FF4BC5F770D7A49D1A3CF2C2DCA6B61`
- [x] 2.2 Add `.sops.yaml` to `infra/clusters/local/kustomization.yaml` resources if needed, or confirm it is a SOPS config file only (not a Kustomize resource — it should NOT be in the resources list)
- [x] 2.3 Add `sops` and `gnupg` to prerequisites listed in project README or CLAUDE.md

## 3. Taskfile Bootstrap Tasks

- [x] 3.1 Add `FLUX_OPERATOR_VERSION` var to `Taskfile.yml` (with a pinned default) and hardcode fingerprint `2D71AD789FF4BC5F770D7A49D1A3CF2C2DCA6B61` as `SOPS_GPG_FINGERPRINT` var (it's not secret)
- [x] 3.2 Add `flux-operator-install` task — applies the flux-operator install manifest from GitHub releases using `FLUX_OPERATOR_VERSION`; uses `kubectl apply --server-side`
- [x] 3.3 Add `sops-provision` task — validates `SOPS_GPG_FINGERPRINT` is set and key exists in local keyring, then runs `gpg --export-secret-keys --armor` and `kubectl create secret generic sops-gpg --from-literal=sops.asc=... -n flux-system --dry-run=client -o yaml | kubectl apply -f -`
- [x] 3.4 Add `flux-bootstrap` task — runs `kubectl apply -k infra/clusters/local/` to apply the FluxInstance and Kustomization objects
- [x] 3.5 Update `cluster-up` task to depend on `flux-operator-install`, `sops-provision`, and then `flux-bootstrap` in sequence (or make `bootstrap` the orchestrating task that calls them in order)
- [x] 3.6 Add `bootstrap` task as the top-level entry point — calls `cluster-up` → `flux-operator-install` → `sops-provision` → `flux-bootstrap` in dependency order
- [x] 3.7 Add `cluster-reset` task — calls `cluster-down` then `bootstrap` for a full teardown + recreate

## 4. GitHub App Secret (Manual Step)

- [x] 4.1 Create `infra/clusters/local/github-secret.yaml` as a plaintext `kind: Secret` template with the expected field names (e.g. `appID`, `installationID`, `privateKey`) but empty values — **STOP HERE and ask the user to fill in the private key contents**
- [x] 4.2 Once the user has filled in the values, run `sops --encrypt --in-place infra/clusters/local/github-secret.yaml` to encrypt with the GPG key
- [x] 4.3 Verify the file is encrypted (values show SOPS ciphertext) and commit it

## 5. Verification

- [ ] 5.1 Run `task bootstrap` from scratch (no existing kind cluster) and confirm the cluster comes up, Flux is installed, and `kubectl get fluxinstance -n flux-system` shows Ready
- [ ] 5.2 Confirm `kubectl get kustomization -n flux-system` shows the infra Kustomization reconciling `infra/k8s/overlays/local`
- [ ] 5.3 Confirm the GitHub secret is decrypted and applied correctly by Flux
- [ ] 5.4 Run `task bootstrap` a second time on the running cluster and confirm it exits without error (idempotency)
- [ ] 5.5 Run `task cluster-reset` and confirm full teardown and clean recreation

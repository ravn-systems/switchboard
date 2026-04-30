## ADDED Requirements

### Requirement: Secrets are encrypted with SOPS + GPG before being committed
The repository SHALL use SOPS with the developer's pre-existing GPG key as the encryption backend for all Kubernetes Secret manifests committed to the repo. Plaintext secrets SHALL NOT be committed.

#### Scenario: Developer encrypts a new secret
- **WHEN** a developer runs `sops --encrypt <secret.yaml>` in a directory covered by `.sops.yaml`
- **THEN** the file is encrypted using the GPG fingerprint defined in the creation rules and can be safely committed

#### Scenario: Unencrypted secret data is not present in git
- **WHEN** the git history is inspected for any `kind: Secret` resource
- **THEN** all such files have SOPS-encrypted values (ciphertext format) in their `data` or `stringData` fields

### Requirement: A .sops.yaml creation rule specifies which files are encrypted and with which GPG key
The `infra/clusters/local/.sops.yaml` file SHALL define a creation rule covering at minimum `infra/**/*secret*.yaml` using the project GPG key fingerprint.

#### Scenario: sops resolves the correct key automatically
- **WHEN** a developer runs `sops --encrypt` on a file matching the creation rule path regex
- **THEN** SOPS uses the configured GPG fingerprint without requiring manual key selection

### Requirement: The GPG private key is provisioned into the cluster during bootstrap
The Taskfile SHALL provide a `sops-provision` task that exports the GPG private key (armored) and creates the `flux-system/sops-gpg` Kubernetes Secret. The GPG fingerprint SHALL be read from the `SOPS_GPG_FINGERPRINT` environment variable or Taskfile var.

#### Scenario: Provisioning succeeds when the key exists in the local keyring
- **WHEN** `task sops-provision` is run and the GPG key for `SOPS_GPG_FINGERPRINT` exists in the local keyring
- **THEN** a Secret named `sops-gpg` is created or updated in the `flux-system` namespace with the exported armored private key in the `sops.asc` field

#### Scenario: Provisioning fails with a clear error when the fingerprint env var is unset
- **WHEN** `task sops-provision` is run and `SOPS_GPG_FINGERPRINT` is not set
- **THEN** the task exits with a non-zero status and prints a message instructing the developer to set `SOPS_GPG_FINGERPRINT`

#### Scenario: Provisioning fails with a clear error when the key is not in the keyring
- **WHEN** `task sops-provision` is run with a fingerprint that does not match any key in the local keyring
- **THEN** the task exits with a non-zero status and prints a message indicating the key was not found

#### Scenario: sops-provision is a dependency of bootstrap
- **WHEN** `task bootstrap` is run
- **THEN** `sops-provision` runs before Flux manifests are applied so the decryption key is available when Flux first reconciles

### Requirement: Flux kustomize-controller is configured to decrypt SOPS secrets using GPG
The Flux Kustomization objects in `clusters/local/` that apply resources containing encrypted secrets SHALL reference `spec.decryption.provider: sops` and `spec.decryption.secretRef.name: sops-gpg`.

#### Scenario: Flux reconciles a Kustomization containing SOPS-encrypted secrets
- **WHEN** Flux's kustomize-controller reconciles a Kustomization with GPG decryption configured
- **THEN** SOPS-encrypted Secret manifests are decrypted and applied as plaintext Kubernetes Secrets in the cluster

#### Scenario: Flux fails clearly when decryption key is missing
- **WHEN** the `sops-gpg` Secret does not exist in `flux-system`
- **THEN** the Kustomization enters a Failed state with an error message referencing decryption failure

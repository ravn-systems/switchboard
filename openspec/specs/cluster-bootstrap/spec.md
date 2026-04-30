## ADDED Requirements

### Requirement: Single bootstrap command brings up the full local stack
The Taskfile SHALL provide a `bootstrap` task that, when run on a machine with `kind`, `kubectl`, `flux` CLI, and internet access, creates the kind cluster, installs the Flux operator, applies the cluster bootstrap config, and waits for all infra to reconcile successfully.

#### Scenario: Fresh bootstrap on a machine with no existing cluster
- **WHEN** `task bootstrap` is run and no kind cluster named `switchboard` exists
- **THEN** a kind cluster is created, the Flux operator is installed, `clusters/local/` is applied, and Flux reconciles all infra workloads without manual intervention

#### Scenario: Bootstrap is re-run on an already-running cluster
- **WHEN** `task bootstrap` is run and the `switchboard` kind cluster already exists
- **THEN** the task skips cluster creation (or is idempotent), re-applies flux manifests, and exits without error

### Requirement: Bootstrap tasks are independently executable
Each phase of bootstrap SHALL be a standalone named task so developers can re-run individual steps without repeating the full sequence.

#### Scenario: Re-installing the Flux operator on an existing cluster
- **WHEN** `task flux-operator-install` is run against an existing cluster
- **THEN** the Flux operator manifest is applied (idempotent) and the task exits successfully

#### Scenario: Re-applying cluster bootstrap config
- **WHEN** `task flux-bootstrap` is run after the operator is installed
- **THEN** the `clusters/local/` manifests are applied and Flux begins reconciling

### Requirement: Cluster teardown removes all resources
The Taskfile SHALL provide a `cluster-down` task that deletes the kind cluster and all resources within it.

#### Scenario: Tearing down the cluster
- **WHEN** `task cluster-down` is run
- **THEN** the kind cluster named `switchboard` is deleted and no Docker containers remain for it

### Requirement: Flux operator version is pinned via a Taskfile variable
The Taskfile SHALL define a `FLUX_OPERATOR_VERSION` variable so the operator version can be updated in one place.

#### Scenario: Overriding the operator version at runtime
- **WHEN** `FLUX_OPERATOR_VERSION=v0.2.0 task flux-operator-install` is run
- **THEN** the specified version of the flux operator manifest is applied

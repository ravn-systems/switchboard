## ADDED Requirements

### Requirement: clusters/local/ is the canonical Flux sync root
The repository SHALL have an `infra/clusters/local/` directory that serves as the sole path Flux watches in its GitRepository. It SHALL contain the FluxInstance and the Flux Kustomization objects that reference infra layers.

#### Scenario: Flux syncs from the correct path
- **WHEN** Flux is bootstrapped and the GitRepository is configured
- **THEN** Flux watches `infra/clusters/local/` and reconciles all resources defined there

#### Scenario: App manifests are not in the sync root
- **WHEN** a developer inspects `infra/clusters/local/`
- **THEN** they see only cluster-orchestration resources (FluxInstance, Kustomization objects) — no Deployment, Service, or StatefulSet resources

### Requirement: Flux Kustomization objects enforce dependency ordering
The `infra/clusters/local/` directory SHALL define Flux Kustomization resources that use `dependsOn` to ensure infra layers reconcile in order: flux-system first, then namespaces, then workloads.

#### Scenario: Infra workloads wait for Flux components
- **WHEN** the FluxInstance is not yet Ready
- **THEN** any Flux Kustomization with `dependsOn: [flux-instance]` does not attempt to reconcile

#### Scenario: Workloads reconcile after dependencies are healthy
- **WHEN** the FluxInstance becomes Ready
- **THEN** dependent Kustomizations begin reconciling in the order defined by their `dependsOn` chain

### Requirement: The old infra/k8s/base/flux/ directory is removed or emptied
The `infra/k8s/base/flux/` directory SHALL be removed after its contents are migrated to `infra/clusters/local/`, so there is no duplicate or conflicting Flux config.

#### Scenario: No stale flux config in the base layer
- **WHEN** a developer lists `infra/k8s/base/`
- **THEN** there is no `flux/` subdirectory, and the base kustomization.yaml does not reference it

### Requirement: clusters/local/ kustomization composes all cluster resources
The `infra/clusters/local/kustomization.yaml` SHALL use Kustomize to compose the FluxInstance and all Flux Kustomization objects, so a single `kubectl apply -k infra/clusters/local/` applies everything needed.

#### Scenario: Single apply brings up cluster-level resources
- **WHEN** `kubectl apply -k infra/clusters/local/` is run against a cluster with the Flux operator installed
- **THEN** the FluxInstance and all Flux Kustomization objects are created

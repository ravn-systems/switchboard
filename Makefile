.PHONY: startk8s
startk8s:
	kind create cluster --config=infra/local/kind/config.yaml

.PHONY: stopk8s 
stopk8s:
	kind delete cluster --name switchboard

.PHONY: kustomize-template kustomize-apply
kustomize-template:
	kubectl kustomize infra/k8s/overlays/local
kustomize-apply:
	kubectl apply -k infra/k8s/overlays/local
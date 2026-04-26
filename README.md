# Switchboard

## Tool Installs
Installation:
```
brew install go-task/tap/go-task
brew install fluxcd/tap/flux
```

## FluxCD Bootstrap Process:

```
helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace
```

```
flux create secret githubapp flux-system \
  --app-id=3505976 \
  --app-installation-id=127138337 \
  --app-private-key=./switchboard-ravnsystems.2026-04-25.private-key.pem
```

## Keycloak Validations

1. OIDC Discovery
```
curl http://localhost:8080/realms/switchboard/.well-known/openid-configuration | jq .
```

2. Token Issuance
```
curl -s -X POST http://localhost:8080/realms/switchboard/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=switchboard" \
  -d "username=user1" \
  -d "password=password" \
  | jq -r .access_token \
  | cut -d. -f2 \
  | awk '{ pad=length($0)%4; if(pad==2) print $0"=="; else if(pad==3) print $0"="; else print $0 }' \
  | base64 -d \
  | jq .
```

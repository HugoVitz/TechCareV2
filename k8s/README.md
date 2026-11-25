# Kubernetes

Ordem de aplicação (o Secret é criado à parte, nunca versionado):

```
kubectl apply -f 00-namespace.yaml -f 01-configmap.yaml
kubectl -n techcare create secret generic techcare-secrets --from-literal=...   # ver 02-secret.exemplo.yaml
kubectl apply -f 10-postgres.yaml          # só em dev/homologação; em produção use o banco gerenciado
kubectl apply -f 20-api.yaml -f 30-console.yaml -f 40-ingress.yaml -f 50-networkpolicy.yaml
kubectl -n techcare rollout status deployment/techcare-api
```

Para testar no próprio computador: Docker Desktop > Settings > Kubernetes > Enable, ou `kind`/`minikube`.

# Zenda GitOps deployment (`argo-deployment` branch)

Project commits: [dandugayathri](https://github.com/dandugayathri/zenda/commits?author=dandugayathri).


kubectl get nodes
kubectl get pods -n argocd
kubectl get application zenda -n argocd
kubectl get pods,deploy,svc -n zenda
kubectl -n zenda rollout status deployment/zenda --timeout=5m
```

Access the app and Argo CD UI:

```sh
kubectl -n zenda port-forward svc/zenda 8080:80
# In another terminal: curl http://localhost:8080/api/health

kubectl -n argocd port-forward svc/argocd-server 8081:443
# Open https://localhost:8081.
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

The Argo CD UI user is `admin`. The initial password is local to the cluster; 


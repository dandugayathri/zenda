# Zenda GitOps deployment (`argo-deployment` branch)

This branch contains the Helm chart, a two-node kind configuration, and an Argo CD Application. The Spring Boot source, Dockerfile, and CI workflow are on `main`.

## Prerequisites

- Docker Desktop running, `kind`, `kubectl`, and `helm` installed.
- Both branches pushed to GitHub by you.
- A public Docker Hub repository named `dandugayathri/zenda`.
- GitHub Actions secret `DOCKERHUB_TOKEN`: a Docker Hub access token with write access to that repository. The workflow uses the public username `dandugayathri`; it does not need a separate username secret. The built-in `GITHUB_TOKEN` needs **Read and write permissions** for repository contents so the workflow can update this branch. No Kubernetes credentials need to be stored in GitHub for a local kind cluster.

## Create the local cluster

Run `bash scripts/bootstrap-kind.sh` on this branch. The script creates one control-plane node and one worker node, creates namespaces `argocd` and `zenda`, installs Argo CD v3.6.1 into `argocd`, and creates the `zenda` Application. It can be run again safely.

Argo CD reads `helm/` from the pushed `argo-deployment` branch. A push to `main` runs the CI workflow, builds and pushes `dandugayathri/zenda:sha-<commit>`, then commits that image tag into `helm/values.yaml` on this branch. Automated sync then deploys it. If the GitHub repository is private, register read access to it in Argo CD before expecting the Application to sync.

Check progress:

```sh
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
# Open https://localhost:8081 (accept the local certificate warning).
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

The Argo CD UI user is `admin`. The initial password is local to the cluster; keep it out of screenshots and Git.

## Assessment evidence

Save at least 10 labeled screenshots in a `screenshots/` directory if required for submission: the local app, successful Docker build, Docker Hub image, green CI run, `kubectl get nodes`, `kubectl get pods -n zenda`, `kubectl get svc -n zenda`, Argo CD Synced/Healthy view, browser page, and `/api/health` response. Capture these after the image has been pushed and Argo CD has synced.

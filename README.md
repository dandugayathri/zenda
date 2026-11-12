# Zenda: Spring Boot CI/CD on a local kind cluster

This project is a small Spring Boot application deployed with Docker, GitHub Actions, Helm and Argo CD. I used two branches:

- `main` has the Java code, tests, Dockerfile and GitHub Actions workflow.
- `argo-deployment` has the kind cluster file, Helm chart and Argo CD Application file.

The flow is simple: I push code to `main` → GitHub Actions tests it and pushes an image to Docker Hub → the workflow updates the image tag in `argo-deployment` → Argo CD sees that change and deploys it to Kubernetes.

The main files are:

| Branch | File | Purpose |
| --- | --- | --- |
| `main` | `src/main/java/com/app/helth/` | Spring Boot application and REST controller |
| `main` | `src/main/resources/static/index.html` | Welcome page |
| `main` | `src/main/resources/application.properties` | App port and Actuator settings |
| `main` | `src/test/java/com/app/helth/` | API and health-check tests |
| `main` | `Dockerfile`, `.github/workflows/actions.yml` | Docker build and CI pipeline |
| `argo-deployment` | `kind-config.yaml`, `helm/`, `argocd/application.yaml` | Cluster, Kubernetes chart and Argo CD setup |

## 1. Install the tools (macOS)

Install Docker Desktop and start it. Wait until Docker says it is running. Then install kind, kubectl and Helm with Homebrew:

```sh
brew install kind kubectl helm
```

Use Java 21 locally to match the Dockerfile and GitHub Actions. Check that everything is available:

```sh
java -version
docker info
kind version
kubectl version --client
helm version
```

The repository includes the Maven wrapper (`mvnw`), so a separate Maven installation is not needed. Docker Desktop must have enough memory for two kind nodes and Argo CD.

## 2. Get the code and run it locally

```sh
git clone https://github.com/dandugayathri/zenda.git
cd zenda
git switch main
./mvnw -B -ntp verify
./mvnw spring-boot:run
```

Open <http://localhost:8080/> to see **Welcome to Zenda**. In another terminal, check the API:

```sh
curl http://localhost:8080/api/health
curl http://localhost:8080/actuator/health
```

`/api/health` returns `{"status":"UP"}`. The app also has `/hello`, liveness and readiness checks under `/actuator/health/`, and Prometheus metrics at `/actuator/prometheus`. The port is set to `8080` in `src/main/resources/application.properties`. Press `Ctrl+C` to stop the app before running the Docker container on the same port.

## 3. Build the Docker image

The `Dockerfile` on `main` builds the app with Maven and runs the JAR with Java 21. Build and test the image locally:

```sh
docker build -t dandugayathri/zenda:local .
docker run --rm -p 8080:8080 dandugayathri/zenda:local
```

Open <http://localhost:8080/> or run `curl http://localhost:8080/api/health` in another terminal. Press `Ctrl+C` to stop the container. The image used for deployment is stored in the public Docker Hub repository `dandugayathri/zenda`, so Kubernetes does not need an image pull secret.

For a manual Docker Hub push, use a Docker Hub access token when `docker login` asks for a password:

```sh
docker login --username dandugayathri
docker build -t dandugayathri/zenda:latest .
docker push dandugayathri/zenda:latest
```

Normally, GitHub Actions does the build and push after a commit reaches `main`.

## 4. Create the two-node kind cluster

Switch to the deployment branch. Its `kind-config.yaml` defines one control-plane node and one worker node:

```sh
git switch argo-deployment
cat kind-config.yaml
kind create cluster --name zenda --config kind-config.yaml --wait 5m
kubectl config use-context kind-zenda
kubectl get nodes
```

If `kind get clusters` already shows `zenda`, skip the `kind create cluster` command and use the existing cluster. Both nodes should show `Ready`.

Create the two namespaces:

```sh
kubectl create namespace argocd
kubectl create namespace zenda
kubectl get namespaces
```

`argocd` holds Argo CD. `zenda` holds the Spring Boot application. If a namespace already exists, there is no need to create it again.

## 5. Check the Helm chart

The chart is in `helm/` on `argo-deployment`. `helm/values.yaml` sets the public Docker Hub image, its tag, one replica and the resource limits. The deployment template uses port `8080` and Actuator liveness and readiness probes. The Service exposes port `80` inside the cluster and sends traffic to the application's port `8080`.

Check the chart before deploying:

```sh
helm lint helm
helm template zenda helm --namespace zenda
```

Helm renders the Kubernetes Deployment and Service from these files. Argo CD uses this same chart when it syncs the application.

## 6. Install Argo CD

Install Argo CD v3.6.1 into the `argocd` namespace and wait for the server:

```sh
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.6.1/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=5m
kubectl get pods -n argocd
```

The `--server-side` option is needed for the large Argo CD resource definitions. The pods should become `Running`.

## 7. Set up GitHub Actions and Docker Hub

Create a **public** Docker Hub repository named `dandugayathri/zenda`. Create a Docker Hub access token that can push images to it. In the GitHub repository, go to **Settings → Secrets and variables → Actions** and add this repository secret:

| Secret | Value |
| --- | --- |
| `DOCKERHUB_TOKEN` | Your Docker Hub access token |

Do not put the token in a file or commit it. The Docker Hub username is already in the workflow, so it is not a secret.

In GitHub, go to **Settings → Actions → General → Workflow permissions** and select **Read and write permissions**. The workflow needs this to update `helm/values.yaml` on `argo-deployment`. If that branch has protection rules, allow the workflow to update it. No kubeconfig or cluster password is stored in GitHub: the cluster is on the local machine, and Argo CD pulls the Git changes from inside the cluster.

The workflow is `.github/workflows/actions.yml` on `main`. On a push to `main`, it runs the Maven tests, builds and pushes `dandugayathri/zenda:latest` and `dandugayathri/zenda:sha-<commit>`, then writes the SHA image tag into `helm/values.yaml` on `argo-deployment`.

Push both branches if they have local commits. Push `argo-deployment` first so the workflow can find it:

```sh
git push origin argo-deployment
git switch main
git push origin main
```

Check the **Actions** tab on GitHub. Wait for **Build and publish** to finish successfully and check that the image appears on Docker Hub.

## 8. Connect Argo CD to the application

After the image is available on Docker Hub, switch back to `argo-deployment` and apply the Argo CD Application file:

```sh
git switch argo-deployment
kubectl apply -f argocd/application.yaml
kubectl get application zenda -n argocd
```

`argocd/application.yaml` tells Argo CD to read the `helm/` folder from the `argo-deployment` branch of this GitHub repository and deploy it into the `zenda` namespace. Automatic sync is enabled, so later image-tag changes are deployed without a manual `helm install` command. If the GitHub repository is private, first give Argo CD read access to it through the Argo CD repository settings.

## 9. Verify the deployment

```sh
kubectl get nodes
kubectl get pods -n argocd
kubectl get pods,deploy,svc -n zenda
kubectl -n zenda rollout status deployment/zenda --timeout=5m
kubectl get application zenda -n argocd
```

The application should be `Synced` and `Healthy`. To open it in your browser:

```sh
kubectl -n zenda port-forward svc/zenda 8080:80
```

Open <http://localhost:8080/> for the welcome page and <http://localhost:8080/api/health> for the health response. Keep the port-forward terminal open while testing.

To open the Argo CD UI, use a second terminal:

```sh
kubectl -n argocd port-forward svc/argocd-server 8081:443
```

Open <https://localhost:8081/> and accept the local certificate warning. The username is `admin`. On macOS, get the initial password with:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -D
```

Keep that password private. To troubleshoot a pod, use `kubectl describe pod -n zenda <pod-name>` and `kubectl logs -n zenda deployment/zenda`.

## 10. Screenshots for the assessment

After the pipeline and deployment work, save at least 10 labeled screenshots in a `screenshots/` folder: the local app, successful Docker build, Docker Hub image, successful GitHub Actions run, `kubectl get nodes`, `kubectl get pods -n zenda`, `kubectl get svc -n zenda`, Argo CD showing Synced/Healthy, the welcome page in the browser, and the `/api/health` response. Do not show tokens or passwords in screenshots.

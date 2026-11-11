# Zenda Spring Boot API (`main` branch)

A Spring Boot REST API with Actuator health and Prometheus metrics. The Helm chart and local kind/Argo CD setup are on `argo-deployment`.

## Run locally

Java 21 and Docker are required. The Maven wrapper downloads Maven 3.9.11 on first use.

```sh
./mvnw -B -ntp verify
./mvnw spring-boot:run
curl http://localhost:8080/api/health
```

The landing page at `/` displays **Welcome to Zenda**. `/api/health` returns JSON `{"status":"UP"}`; `/hello` returns a greeting; `/actuator/health`, `/actuator/health/liveness`, `/actuator/health/readiness`, and `/actuator/prometheus` provide operational checks.

## Build and publish an image manually

```sh
docker build -t dandugayathri/zenda:latest .
docker login --username dandugayathri
docker push dandugayathri/zenda:latest
```

Use a Docker Hub access token when prompted, not your account password. The public image can be pulled by Kubernetes without an image pull secret.

## GitHub Actions and GitOps

Create the public Docker Hub repository `dandugayathri/zenda`. Add repository Actions secret `DOCKERHUB_TOKEN` with a Docker Hub access token that has write access to it. In GitHub repository Settings → Actions → General → Workflow permissions, allow **Read and write permissions** for `GITHUB_TOKEN`. No separate Docker username, Kubernetes, or Argo CD secret is needed for this local kind setup. If `argo-deployment` is protected, permit the Actions bot to push its image-tag update.

Push `argo-deployment` first, then `main`. Each push to `main` runs tests, builds and pushes `latest` and `sha-<commit>` images, then commits the immutable SHA tag to the Helm values in `argo-deployment`. Argo CD auto-syncs that branch. The local cluster setup and access commands are in the `argo-deployment` README.

## Submission evidence

After deployment, capture the 10 labeled screenshots listed in the `argo-deployment` README and place them in a `screenshots/` directory. Do not include credentials or tokens in screenshots.

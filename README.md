# Docker Mastery Assignment

This project containerises a real Flask web application, pushes the image to three different container registries (DockerHub, GHCR, and ECR), and orchestrates a multi-service application using Docker Compose. It also covers multi-stage builds to minimise image size, a CI/CD pipeline with GitHub Actions, and pushing to ACR as a bonus.


## What the App Does

When you hit the root endpoint, it returns a JSON response with a greeting, the container's hostname, and a running visit count stored in Redis. There's also a `/health` endpoint for health checks.


## Docker Image Registry URLs

Below are the locations where this image has been published.

- DockerHub: `docker.io/brightv1/flask-app:latest`  

- GHCR (GitHub Container Registry): `ghcr.io/bright-1h/flask-app:latest`

- ECR (Amazon Elastic Container Registry): `922685583704.dkr.ecr.us-east-1.amazonaws.com/flask-app`  

- ACR (Azure Container Registry) — bonus: `brightadzibolosu.azurecr.io/flask-app`  


## Multi-Stage Build

One of the goals of this assignment was to reduce the final image size as much as possible. The original Dockerfile used a single `python:3.11-slim` base and installed everything into it — which works, but leaves behind pip, setuptools, and other build-time tools that the running app never needs.

The rewritten Dockerfile uses two stages:

- Stage 1 (`builder`) — uses `python:3.11-slim` to create a virtual environment and install all dependencies from `requirements.txt` into it.
- Stage 2 (`runtime`) — starts fresh from `python:3.11-alpine` (a much smaller base) and copies only the pre-built `/venv` and `app.py` across. Nothing from the builder stage leaks in.

### Size comparison

Here's the output of `docker images` after building both versions:

```
REPOSITORY   TAG    IMAGE ID       CREATED AT                      SIZE
flask-app    v1.0   f8a79b8ea2b0   2026-05-14 21:02:36 +0000 GMT   214MB
flask-app    v2.0   b8476dafaef9   2026-05-14 21:02:36 +0000 GMT   132MB
```

That's a reduction from 214MB down to 132MB — **38% smaller** — without touching a single line of application code.


## `.dockerignore`

Sending unnecessary files to the Docker build daemon wastes time and risks leaking secrets into image layers. The `.dockerignore` file excludes the following:

- `venv/`, `.venv/` — the local Python virtual environment. It's host-specific, potentially hundreds of MB, and would be incompatible inside the container anyway. Dependencies are installed fresh via `requirements.txt`.
- `__pycache__/`, `*.py[cod]`, `*.pyo` — compiled bytecode. Python regenerates these at runtime and they're tied to the local interpreter version.
- `.env`, `.env.*` — contains secrets like API keys and credentials. These should never end up inside an image layer, even accidentally.
- `.git/`, `.gitignore` — version control history is not needed at runtime and can add significant size.
- `.github/` — CI/CD workflow definitions have no purpose inside a container.
- `Dockerfile`, `docker-compose.yml`, `.dockerignore` — build tooling, not application code.
- `README.md` — documentation doesn't belong in a production image.
- `.DS_Store`, `Thumbs.db` — macOS and Windows OS artefacts that should never ship because they are not needed by the app.


## CI/CD — Automated Builds with GitHub Actions

Every push to `main` triggers a GitHub Actions workflow (`.github/workflows/docker.yml`) that:

1. Checks out the repository
2. Sets up Docker Buildx
3. Logs in to GHCR using the built-in `GITHUB_TOKEN` (no manual secret needed)
4. Builds the image and pushes it with two tags: `latest` and a short git SHA (e.g. `sha-a1b2c3d`)
5. Uses GitHub Actions layer cache so unchanged layers are skipped on subsequent runs


## Running Locally

Make sure you have Docker and Docker Compose installed, then run:

```bash
docker compose up --build -d
```

The app will be available at http://localhost:5000.

- `GET /` — Returns a greeting, the container hostname, and the current Redis visit count
- `GET /health` — Returns `{"status": "ok"}`, used by Docker to determine if the container is healthy


## Challenges & How I Resolved Them

1. Container failed to start — Flask dependencies not installed  
When I first tried to run the flask-app container, it crashed immediately because Flask and its dependencies weren't being installed. I had the `requirements.txt` file in the project but hadn't added the `COPY requirements.txt .` and `RUN pip install` steps to the Dockerfile yet. Once I added those two lines (before copying the rest of the application code), the container started up correctly.

2. App service was unhealthy after `docker compose up --build -d`  
After bringing up the stack, `docker-assignment-web-1` was reporting as unhealthy. The health check in `docker-compose.yml` was using `curl -f http://localhost:5000/health`, but `python:3.11-slim` doesn't ship with `curl` installed. Rather than installing `curl` just for the health check (which would add unnecessary weight to the image), I replaced it with a pure Python one-liner using the built-in `urllib.request` module:
```yaml
test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"]
```
This solved the unhealthy status without adding any extra dependencies.

3. ACR creation failed — unregistered subscription namespace  
When running the `az acr create` command to provision the Azure Container Registry, I got an error saying my subscription wasn't registered to use the `Microsoft.ContainerRegistry` namespace. I resolved this by going to the Azure Portal → Subscriptions → Resource Providers, searching for `Microsoft.ContainerRegistry`, and clicking Register. Once the registration completed, I re-ran the command and the registry was created successfully.

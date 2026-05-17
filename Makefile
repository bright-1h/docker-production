REGISTRY   := ghcr.io/bright-1h
IMAGE_NAME := docker-production
IMAGE_TAG  ?= latest
IMAGE      := $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

COMPOSE    := docker compose
STACK_NAME := myapp

.PHONY: help build run stop clean scan push logs deploy undeploy

help:
	@echo ""
	@echo "Usage: make <target> [IMAGE_TAG=<tag>]"
	@echo ""
	@echo "  build     Build the image: $(IMAGE)"
	@echo "  run       Start the full stack locally (docker compose up --build -d)"
	@echo "  stop      Stop the local stack (docker compose down)"
	@echo "  clean     Stop stack and remove volumes + images"
	@echo "  scan      Scan the image with Trivy (HIGH/CRITICAL only)"
	@echo "  push      Push the image to GHCR"
	@echo "  logs      Follow logs for all services"
	@echo "  deploy    Deploy to Docker Swarm (inits swarm if needed)"
	@echo "  undeploy  Remove the Swarm stack"
	@echo ""

build:
	docker build -t $(IMAGE) .

run:
	$(COMPOSE) up --build --force-recreate -d

stop:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v --rmi all

scan:
	trivy image --severity HIGH,CRITICAL $(IMAGE)

push:
	docker push $(IMAGE)

logs:
	$(COMPOSE) logs -f

deploy:
	docker swarm init 2>/dev/null || true
	docker stack deploy -c docker-compose.yml -c docker-compose.swarm.yml $(STACK_NAME)

undeploy:
	docker stack rm $(STACK_NAME)

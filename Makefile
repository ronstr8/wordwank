# Wordwank Polyglot Stack Makefile

REGISTRY ?= docker.io/wordwank
TAG ?= latest

SERVICES = frontend gatewayd tilemasters playerd wordd dictd

.PHONY: all build clean deploy undeploy help $(SERVICES)

all: build

help:
	@echo "Wordwank Build System"
	@echo "Usage:"
	@echo "  make build         - Build all microservice Docker images"
	@echo "  make deploy        - Install/Upgrade using Helm umbrella chart"
	@echo "  make undeploy      - Uninstall Helm release"
	@echo "  make clean         - Remove local build artifacts (dist, target, etc.)"
	@echo "  make <service>     - Build a specific service (e.g., make frontend)"

# Docker Build Targets
build: $(SERVICES)

frontend:
	docker build -t $(REGISTRY)/frontend:$(TAG) ./srv/frontend

gatewayd:
	docker build -t $(REGISTRY)/gatewayd:$(TAG) ./srv/gatewayd

tilemasters:
	docker build -t $(REGISTRY)/tilemasters:$(TAG) ./srv/tilemasters

playerd:
	docker build -t $(REGISTRY)/playerd:$(TAG) ./srv/playerd

wordd:
	docker build -t $(REGISTRY)/wordd:$(TAG) ./srv/wordd

dictd:
	docker build -t $(REGISTRY)/dictd:$(TAG) ./srv/dictd

# Helm Commands
deploy:
	helm dependency update ./charts/wordwank
	helm upgrade --install wordwank ./charts/wordwank --values ./charts/wordwank/values.yaml

undeploy:
	helm uninstall wordwank

# Cleanup
clean:
	@echo "Cleaning up local artifacts..."
	rm -rf srv/frontend/dist
	rm -rf srv/frontend/node_modules
	rm -rf srv/wordd/target
	rm -rf srv/playerd/target
	find . -name ".precomp" -type d -exec rm -rf {} +
	rm -f srv/gatewayd/gatewayd

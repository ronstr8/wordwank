# Wordwank Polyglot Stack Makefile

# Localhost is always allowed as an insecure registry by Docker
REGISTRY = localhost:5000
TAG ?= latest
DOCKER_BUILD_FLAGS ?= --progress=plain
NAMESPACE = wordwank
DOMAIN = arkham.fazigu.org

SERVICES = frontend gatewayd tilemasters playerd wordd dictd

.PHONY: all build clean deploy undeploy help $(SERVICES) minikube-setup registry-tunnel metallb-install metallb-config

all: build

help:
	@echo "Wordwank Build System (Minikube Optimized)"
	@echo "Usage:"
	@echo "  make build         - Build and PUSH all microservice Docker images"
	@echo "  make deploy        - Install/Upgrade using Helm umbrella chart"
	@echo "  make minikube-setup - Enable registry and ingress addons"
	@echo "  make metallb-install - Install MetalLB manifests directly"
	@echo "  make metallb-config - Configure MetalLB with a default IP range"
	@echo "  make expose        - Proxy Arkham:80 to Minikube Ingress (run as root)"
	@echo "  make <service>     - Build, Push, and Restart a specific service"

# Step 1: Prepare Minikube for our production-like workflow
minikube-setup:
	@echo "Enabling Minikube addons..."
	minikube addons enable registry
	minikube addons enable ingress

# Step 2: Install MetalLB directly (more reliable than the addon)
# We use the manifests from the official MetalLB repository
metallb-install:
	@echo "Applying MetalLB manifests..."
	@kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
	@echo "Waiting for MetalLB pods to be ready..."
	@kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=120s

# Step 3: Configure MetalLB with a range that matches the Minikube network
metallb-config:
	@echo "Waiting for MetalLB CRDs to be established..."
	@kubectl wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io || (echo "CRDs not found. Did you run 'make metallb-install'?" && exit 1)
	@echo "Configuring MetalLB IP range..."
	@MINIKUBE_IP=$$(minikube ip); \
	BASE_IP=$${MINIKUBE_IP%.*}; \
	RANGE_START="$$BASE_IP.100"; \
	RANGE_END="$$BASE_IP.110"; \
	echo "Assigning MetalLB range: $$RANGE_START-$$RANGE_END"; \
	sed "s/RANGE_START/$$RANGE_START/; s/RANGE_END/$$RANGE_END/" charts/wordwank/resources/metallb-config.yaml | kubectl apply -f -

# Step 4: Expose the Ingress to the 192.168.1.0 network
# This requires 'socat' installed on Arkham and sudo privileges
expose:
	@echo "Bridging Arkham:80 to Minikube Ingress..."
	@INGRESS_IP=$$(kubectl get ingress -n $(NAMESPACE) wordwank-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	if [ -z "$$INGRESS_IP" ]; then echo "Error: Ingress doesn't have an IP yet. Did you run make deploy and make metallb-config?"; exit 1; fi; \
	echo "Ingress IP is $$INGRESS_IP. Starting proxy..."; \
	sudo socat TCP4-LISTEN:80,fork,reuseaddr TCP4:$$INGRESS_IP:80

# Step 5: Start a background tunnel to the Minikube registry
registry-tunnel:
	@echo "Ensuring registry tunnel is running..."
	@kubectl port-forward --namespace kube-system service/registry 5000:80 > /dev/null 2>&1 &
	@sleep 2

# Docker Build & Push Targets
build: $(SERVICES)

frontend: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/frontend:$(TAG) ./srv/frontend
	docker push $(REGISTRY)/frontend:$(TAG)
	kubectl rollout restart deployment/frontend -n $(NAMESPACE) || true

gatewayd: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/gatewayd:$(TAG) ./srv/gatewayd
	docker push $(REGISTRY)/gatewayd:$(TAG)
	kubectl rollout restart deployment/gatewayd -n $(NAMESPACE) || true

tilemasters: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/tilemasters:$(TAG) ./srv/tilemasters
	docker push $(REGISTRY)/tilemasters:$(TAG)
	kubectl rollout restart deployment/tilemasters -n $(NAMESPACE) || true

playerd: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/playerd:$(TAG) ./srv/playerd
	docker push $(REGISTRY)/playerd:$(TAG)
	kubectl rollout restart deployment/playerd -n $(NAMESPACE) || true

wordd: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordd:$(TAG) ./srv/wordd
	docker push $(REGISTRY)/wordd:$(TAG)
	kubectl rollout restart deployment/wordd -n $(NAMESPACE) || true

dictd: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/dictd:$(TAG) ./srv/dictd
	docker push $(REGISTRY)/dictd:$(TAG)
	kubectl rollout restart deployment/dictd -n $(NAMESPACE) || true

# Helm Commands
deploy: minikube-setup
	helm dependency update ./charts/wordwank
	helm upgrade --install wordwank ./charts/wordwank \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--values ./charts/wordwank/values.yaml \
		--set global.registry=localhost:5000 \
		--set global.domain=$(DOMAIN)

undeploy:
	helm uninstall wordwank --namespace $(NAMESPACE)

# Cleanup
clean:
	@echo "Cleaning up local artifacts..."
	rm -rf srv/frontend/dist
	rm -rf srv/frontend/node_modules
	rm -rf srv/wordd/target
	rm -rf srv/playerd/target
	rm -f srv/gatewayd/gatewayd
	find . -name "*.exe" -delete
	find . -name "tilemasters" -type f -not -path "./srv/tilemasters/cmd/tilemasters/*" -delete

# Wordwank Polyglot Stack Makefile

# Localhost is always allowed as an insecure registry by Docker
REGISTRY = localhost:5000
# Single point of truth for versions is helm/values.yaml
TAG ?= $(shell grep -m 1 "imageTag:" helm/values.yaml | sed 's/.*imageTag:[[:space:]]*//' | tr -d ' "')
DOCKER_BUILD_FLAGS ?= --progress=plain
NAMESPACE = wordwank
DOMAIN = wordwank.fazigu.org

SERVICES = frontend backend wordd

.PHONY: all build clean deploy undeploy help $(SERVICES) minikube-setup registry-tunnel metallb-install metallb-config cert-manager-setup

all: build

help:
	@echo "Wordwank Build System (Minikube Optimized)"
	@echo "Usage:"
	@echo "  make build              - Build and PUSH all microservice Docker images"
	@echo "  make deploy             - Install/Upgrade using Helm umbrella chart"
	@echo "  make minikube-setup     - Enable registry and ingress addons"
	@echo "  make metallb-install    - Install MetalLB manifests directly"
	@echo "  make metallb-config     - Configure MetalLB with a default IP range"
	@echo "  make cert-manager-setup - Install cert-manager and configure Let's Encrypt"
	@echo "  make expose             - Proxy localhost:80/443 to Minikube Ingress (run as root)"
	@echo "  make <service>          - Build, Push, and Restart a specific service"

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
	sed "s/RANGE_START/$$RANGE_START/; s/RANGE_END/$$RANGE_END/" helm/resources/metallb-config.yaml | kubectl apply -f -

# Step 4: Install cert-manager and configure Let's Encrypt
cert-manager-setup:
	@echo "Installing cert-manager..."
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml
	@echo "Waiting for cert-manager to be ready..."
	@kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=180s || true
	@echo "Patching cert-manager for internal domain resolution..."
	@bash helm/resources/patch-cert-manager-hosts.sh
	@echo "⚠️  IMPORTANT: Edit helm/resources/letsencrypt-issuer.yaml and replace email if not done yet"
	@echo "Applying Let's Encrypt ClusterIssuer..."
	@kubectl apply -f helm/resources/letsencrypt-issuer.yaml
	@echo "✅ Cert-manager setup complete!"
	@echo "   - Cert-manager configured to resolve $(DOMAIN) internally"
	@echo "   - Using letsencrypt-prod issuer for trusted certificates"

# Step 5: Expose the Ingress to the network (HTTP and HTTPS)
# This requires 'socat' installed and sudo privileges
expose:
	@echo "Bridging 0.0.0.0:80 and 0.0.0.0:443 to Minikube Ingress..."
	@INGRESS_IP=$$(kubectl get ingress -n $(NAMESPACE) ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	if [ -z "$$INGRESS_IP" ]; then echo "Error: Ingress doesn't have an IP yet. Did you run make deploy and make metallb-config?"; exit 1; fi; \
	echo "Ingress IP is $$INGRESS_IP. Starting proxies..."; \
	echo "Starting HTTP proxy on :80..."; \
	sudo socat TCP4-LISTEN:80,fork,reuseaddr TCP4:$$INGRESS_IP:80 & \
	echo "Starting HTTPS proxy on :443..."; \
	sudo socat TCP4-LISTEN:443,fork,reuseaddr TCP4:$$INGRESS_IP:443 & \
	echo "✅ Proxies started. Press Ctrl+C to stop both."; \
	wait

# Step 5: Start a background tunnel to the Minikube registry
registry-tunnel:
	@echo "Ensuring registry tunnel is running..."
	@kubectl port-forward --namespace kube-system service/registry 5000:80 > /dev/null 2>&1 &
	@sleep 2

# Docker Build & Push Targets
build: $(SERVICES)

frontend: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordwank-frontend:$(TAG) ./srv/frontend
	docker push $(REGISTRY)/wordwank-frontend:$(TAG)
	kubectl rollout restart deployment/frontend -n $(NAMESPACE) || true
	kubectl rollout status deployment/frontend -n $(NAMESPACE) || true

wordd: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordwank-wordd:$(TAG) ./srv/wordd
	docker push $(REGISTRY)/wordwank-wordd:$(TAG)
	kubectl rollout restart deployment/wordd -n $(NAMESPACE) || true
	kubectl rollout status deployment/wordd -n $(NAMESPACE) || true

backend: minikube-setup registry-tunnel
	docker build $(DOCKER_BUILD_FLAGS) -t $(REGISTRY)/wordwank-backend:$(TAG) ./srv/backend
	docker push $(REGISTRY)/wordwank-backend:$(TAG)
	kubectl rollout restart deployment/backend -n $(NAMESPACE) || true
	kubectl rollout status deployment/backend -n $(NAMESPACE) || true


# Helm Commands
# i18n Note: Master truth lives in helm/share/locale/
# Both frontend and backend mount the wordwank-locales ConfigMap.

# Setup persistent storage directory on host
setup-storage:
	@echo "Creating persistent storage directory..."
	@sudo install -d -m 775 -g root $$HOME/.local/share/k8s-volumes/wordwank/postgresql
	@echo "✅ Storage directory ready at $$HOME/.local/share/k8s-volumes/wordwank/postgresql"

deploy: minikube-setup setup-storage
	helm dependency update ./helm
	helm upgrade --install wordwank ./helm \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--values ./helm/values.yaml \
		--values ./helm/secrets.yaml \
		--set global.registry=localhost:5000 \
		--set global.domain=$(DOMAIN) \
		--set persistence.hostBasePath=$$HOME/.local/share/k8s-volumes

undeploy:
	helm uninstall wordwank --namespace $(NAMESPACE)

# Hot-reload i18n via ConfigMap
locales:
	@echo "Updating shared locales ConfigMap..."
	@kubectl create configmap wordwank-locales \
		--namespace $(NAMESPACE) \
		--from-file=en.json=helm/share/locale/en.json \
		--from-file=es.json=helm/share/locale/es.json \
		--from-file=fr.json=helm/share/locale/fr.json \
		--dry-run=client -o yaml | kubectl apply --namespace $(NAMESPACE) -f -
	@echo "✅ ConfigMap updated. Pods will pick up changes within 5 minutes."

# Cleanup
clean:
	@echo "Cleaning up local artifacts..."
	rm -rf helm/share
	rm -rf srv/frontend/dist
	rm -rf srv/frontend/node_modules
	rm -rf srv/wordd/target
	rm -rf srv/playerd/target
	rm -f srv/gatewayd/gatewayd
	find . -name "*.exe" -delete
	find . -name "tilemasters" -type f -not -path "./srv/tilemasters/cmd/tilemasters/*" -delete

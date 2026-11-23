# logodal Polyglot Stack Makefile

# Localhost is always allowed as an insecure registry by Docker
REGISTRY = localhost:5000
# Images are tagged with the commit they were built from (scripts/image-tag.sh).
# VERSION only labels the changelog; it doesn't name images.
ifndef TAG
TAG := $(shell scripts/image-tag.sh)
endif
PROJECT_NAME ?= logodal
DOCKER_BUILD_FLAGS ?= --progress=plain
NAMESPACE = logodal
DOMAIN = logodal.fazigu.org

SERVICES = frontend backend wordd

.PHONY: all build clean deploy resurrect undeploy help backup verify-registry ensure-namespace sync-version $(SERVICES)

all: build

help:
	@echo "logodal Build System (Kind)"
	@echo "Usage:"
	@echo "  make build              - Build and push all microservice Docker images"
	@echo "  make deploy             - Install/Upgrade using Helm umbrella chart"
	@echo "  make <service>          - Build, push and roll out a service, tagged with the commit SHA"
	@echo "  make resurrect          - Run after bringing back up a cluster"

ensure-namespace:
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

# Docker Build & Push Targets
build: $(SERVICES)

$(SERVICES): ensure-namespace
	docker build $(DOCKER_BUILD_FLAGS) --build-arg GIT_SHA=$(TAG) -t $(REGISTRY)/$(PROJECT_NAME)-$@:$(TAG) ./srv/$@
	docker push $(REGISTRY)/$(PROJECT_NAME)-$@:$(TAG)
	scripts/roll-service.sh $@ $(REGISTRY)/$(PROJECT_NAME)-$@:$(TAG) $(NAMESPACE)

sync-version: ## Propagate VERSION to package.json and Chart.yaml appVersions
	node scripts/sync-version.js

migrate: ## Run pending database migrations inside the cluster
	kubectl exec -n $(NAMESPACE) -it deploy/backend -- perl -Ilib bin/migrate.pl

verify-registry: ## Check every tag in the local registry still has all its manifests and layers
	scripts/verify-registry.py $(REGISTRY)

backup: ## Create a timestamped SQL backup of the logodal database
	bash scripts/backup-db.sh


# Helm Commands
# i18n Note: Master truth lives in srv/frontend/share/locale/
# Both frontend and backend mount the logodal-locales ConfigMap.

deploy: ensure-namespace
	node scripts/sync-version.js
	@mkdir -p helm/share/locale
	@cp srv/frontend/share/locale/*.json helm/share/locale/
	helm dependency build ./helm
	@# Keep each service on the image it's running; check them all before touching anything.
	@tags=$$(scripts/deployed-tags.sh $(NAMESPACE) $(REGISTRY) $(PROJECT_NAME) $(TAG) $(SERVICES)) || exit 1; \
	set -x; \
	kubectl delete configmap logodal-locales --namespace $(NAMESPACE) --ignore-not-found && \
	helm upgrade --install logodal ./helm \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--values ./helm/values.yaml \
		--values ./helm/secrets.yaml \
		--set global.registry=$(REGISTRY) \
		--set global.domain=$(DOMAIN) \
		$$tags

undeploy:
	helm uninstall logodal --namespace $(NAMESPACE)

# Hot-reload i18n via ConfigMap
locales:
	@echo "Updating shared locales ConfigMap..."
	@kubectl delete configmap logodal-locales --namespace $(NAMESPACE) --ignore-not-found
	@kubectl create configmap logodal-locales \
		--namespace $(NAMESPACE) \
		--from-file=srv/frontend/share/locale/
	@echo "✅ ConfigMap updated. Pods will pick up changes within 5 minutes."

# Lexicon generation from Hunspell dictionaries
HUNSPELL_DICTS ?= /usr/share/hunspell
WORDD_ROOT ?= srv/wordd/share/words
LANGS = de el en es fr ru

lexicon:
	@if [ -z "$(LANG)" ]; then echo "Usage: make lexicon LANG=en"; exit 1; fi
	@echo "Generating lexicon for $(LANG)..."
	@mkdir -p $(WORDD_ROOT)/$(LANG)
	@find $(HUNSPELL_DICTS) -name "$(LANG)_[A-Z]*.dic" | xargs perl scripts/hunspell-to-lexicon.pl > $(WORDD_ROOT)/$(LANG)/lexicon.txt
	@echo "✅ $(LANG) lexicon generated: $$(wc -l < $(WORDD_ROOT)/$(LANG)/lexicon.txt) words"

lexicons:
	@for lang in $(LANGS); do \
		$(MAKE) lexicon LANG=$$lang; \
	done
	@echo "✅ All lexicons generated."
	@wc -l $(WORDD_ROOT)/*/lexicon.txt

# Cleanup
clean:
	@echo "Cleaning up local artifacts..."
	rm -rf helm/share
	rm -rf srv/frontend/dist
	rm -rf srv/frontend/node_modules
	rm -rf srv/wordd/target
	find . -name "*.exe" -delete

resurrect: clean build deploy

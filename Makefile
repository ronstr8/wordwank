NAMESPACE ?= wordwank
GLOBAL_VALUES ?= ./global-values.yaml
REGISTRY ?= ghcr.io/ronstr8

deploy-wordd:
	helm upgrade --install wordd srv/wordd/helm --namespace $(NAMESPACE) -f $(GLOBAL_VALUES) --create-namespace

deploy-dictd:
	helm upgrade --install dictd srv/dictd/helm --namespace $(NAMESPACE) -f $(GLOBAL_VALUES)

deploy-all: deploy-wordd deploy-dictd

# Build and push dictd
build-dictd:
	docker build -t $(REGISTRY)/dictd:latest srv/dictd

push-dictd: build-dictd
	docker push $(REGISTRY)/dictd:latest

build-push-dictd: build-dictd push-dictd

# Build and push wordd
build-wordd:
	docker build -t $(REGISTRY)/wordd:latest srv/wordd

push-wordd: build-wordd
	docker push $(REGISTRY)/wordd:latest

build-push-wordd: build-wordd push-wordd

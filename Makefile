
NAMESPACE ?= wordwank
GLOBAL_VALUES ?= ./global-values.yaml

deploy-wordd:
	helm upgrade --install wordd srv/wordd/helm --namespace $(NAMESPACE) -f $(GLOBAL_VALUES) --create-namespace

deploy-dictd:
	helm upgrade --install dictd srv/dictd/helm --namespace $(NAMESPACE) -f $(GLOBAL_VALUES)

deploy-all: deploy-wordd deploy-dictd

build-dictd:
	docker build -t ghcr.io/ronstr8/dictd:latest srv/dictd

push-dictd: build-dictd
	docker push ghcr.io/ronstr8/dictd:latest

build-push-dictd: build-dictd push-dictd

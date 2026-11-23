#!/usr/bin/env bash
# Usage: roll-service.sh <service> <image> <namespace>
#
# Points a running deployment at a freshly pushed image and waits for it.
# Changing the image rolls the pods by itself; when the image is unchanged
# (a rebuilt -dirty tag) we restart instead, so the new build still gets pulled.
set -euo pipefail

service=$1 image=$2 namespace=$3

if ! kubectl get deployment "$service" -n "$namespace" >/dev/null 2>&1; then
    echo "⚠️  deployment/$service not found in namespace $namespace. Run 'make deploy' first."
    exit 0
fi

current=$(kubectl get deployment "$service" -n "$namespace" \
    -o jsonpath='{.spec.template.spec.containers[0].image}')

if [ "$current" = "$image" ]; then
    kubectl rollout restart deployment/"$service" -n "$namespace"
else
    kubectl set image deployment/"$service" "*=$image" -n "$namespace"
fi
kubectl rollout status deployment/"$service" -n "$namespace"

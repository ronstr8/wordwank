#!/usr/bin/env bash
# Usage: deployed-tags.sh <namespace> <registry> <project> <fallback-tag> <service>...
#
# Prints "--set <service>.imageTag=<tag>" flags for helm, so a deploy keeps
# each service on the image it's already running. Services are built one at a
# time (make backend, make frontend...), so they rarely share a tag, and
# HEAD's tag only exists for services rebuilt since the last commit.
# A service that isn't running yet (fresh cluster) gets <fallback-tag>.
# Exits non-zero if any chosen image is missing from the registry, so helm
# never rolls pods onto an image that can't be pulled.
set -euo pipefail

namespace=$1 registry=$2 project=$3 fallback=$4
shift 4

missing=0
for service in "$@"; do
    image=$(kubectl get deployment "$service" -n "$namespace" \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
    tag=${image:+${image##*:}}
    tag=${tag:-$fallback}

    if ! curl -sf -o /dev/null \
        -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
        -H 'Accept: application/vnd.oci.image.index.v1+json' \
        "http://$registry/v2/$project-$service/manifests/$tag"; then
        echo "❌ $registry/$project-$service:$tag is not in the registry. Run 'make $service' first." >&2
        missing=1
    fi
    printf -- '--set %s.imageTag=%s ' "$service" "$tag"
done
echo
exit "$missing"

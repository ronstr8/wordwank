#!/bin/bash
# Script to add hostAliases to cert-manager deployment for NAT environments
# This allows cert-manager HTTP-01 self-check to work behind NAT

set -e

NAMESPACE="wordwank"
DOMAIN="wordwank.fazigu.org"

echo "🔍 Detecting internal Ingress IP..."

# Try multiple methods to find the right IP
INGRESS_IP=""

# Method 1: Get the ingress LoadBalancer IP (MetalLB assigned)
INGRESS_IP=$(kubectl get ingress ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$INGRESS_IP" ]; then
  echo "⚠️  LoadBalancer IP not found, trying service ClusterIP..."
  # Method 2: Get the frontend service ClusterIP
  INGRESS_IP=$(kubectl get svc frontend -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
fi

if [ -z "$INGRESS_IP" ]; then
  echo "❌ Could not determine Ingress IP automatically."
  echo "Please find your Ingress IP manually with:"
  echo "  kubectl get ingress ingress -n $NAMESPACE"
  echo "Then run:"
  echo "  kubectl patch deployment cert-manager -n cert-manager --type=json -p='[{\"op\":\"add\",\"path\":\"/spec/template/spec/hostAliases\",\"value\":[{\"ip\":\"YOUR_IP_HERE\",\"hostnames\":[\"$DOMAIN\"]}]}]'"
  exit 1
fi

echo "✅ Found IP: $INGRESS_IP"
echo "📝 Patching cert-manager deployment..."

# Check if hostAliases already exists
if kubectl get deployment cert-manager -n cert-manager -o yaml | grep -q "hostAliases:"; then
  echo "⚠️  hostAliases already exists, removing old entry..."
  kubectl patch deployment cert-manager -n cert-manager --type=json -p='[{"op":"remove","path":"/spec/template/spec/hostAliases"}]' || true
  sleep 2
fi

# Add hostAliases
kubectl patch deployment cert-manager -n cert-manager --type=json -p="[
  {
    \"op\": \"add\",
    \"path\": \"/spec/template/spec/hostAliases\",
    \"value\": [
      {
        \"ip\": \"$INGRESS_IP\",
        \"hostnames\": [\"$DOMAIN\"]
      }
    ]
  }
]"

echo "✅ Patch applied! Waiting for cert-manager to restart..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s

echo ""
echo "✅ Done! Cert-manager now resolves $DOMAIN -> $INGRESS_IP internally"
echo ""
echo "Verify with:"
echo "  kubectl get deployment cert-manager -n cert-manager -o yaml | grep -A 10 hostAliases"
echo ""
echo "To test certificate issuance:"
echo "  kubectl delete certificate --all -n $NAMESPACE"
echo "  kubectl delete secret wordwank-tls -n $NAMESPACE"
echo "  make deploy"
echo "  kubectl get certificate -n $NAMESPACE -w"

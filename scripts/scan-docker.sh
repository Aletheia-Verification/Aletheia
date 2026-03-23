#!/usr/bin/env bash
# scan-docker.sh — Local Docker image CVE scanning with Trivy
#
# Usage:
#   ./scripts/scan-docker.sh              # Build + scan
#   ./scripts/scan-docker.sh --skip-build # Scan existing image
#
# Requires: docker, trivy (brew install trivy / apt install trivy)

set -euo pipefail

IMAGE="aletheia:scan"
REPORT="trivy-report.json"

# Build unless --skip-build
if [[ "${1:-}" != "--skip-build" ]]; then
    echo "==> Building Docker image..."
    docker build -t "$IMAGE" .
fi

echo ""
echo "==> Scanning for CRITICAL vulnerabilities (will fail if found)..."
trivy image --exit-code 1 --severity CRITICAL "$IMAGE"

echo ""
echo "==> Scanning for HIGH vulnerabilities (advisory)..."
trivy image --exit-code 0 --severity HIGH "$IMAGE"

echo ""
echo "==> Generating full JSON report..."
trivy image --format json --output "$REPORT" "$IMAGE"
echo "    Report saved to $REPORT"

echo ""
echo "==> Summary:"
trivy image --severity CRITICAL,HIGH --format table "$IMAGE"

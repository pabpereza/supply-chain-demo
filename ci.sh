#!/usr/bin/env bash
# "Pipeline" local de la demo: build, escaneo, push, firma y actualización de deploy/.
# Uso: ./ci.sh            (SCAN=0 o SIGN=0 para desactivar pasos)
# La clave privada solo existe en el terminal de CI: COSIGN_KEY=ruta/cosign.key
set -euo pipefail

REPO=${REPO:-docker.io/pabpereza/supply-chain-demo}
TAG=${TAG:-$(git rev-parse --short HEAD)}
SCAN=${SCAN:-1}
SIGN=${SIGN:-1}
COSIGN_KEY=${COSIGN_KEY:-$HOME/.config/supply-chain-demo/cosign.key}

echo "▶ build $REPO:$TAG"
docker build -q -t "$REPO:$TAG" app/

if [[ $SCAN == 1 ]]; then
  echo "▶ trivy (falla si hay CRITICAL)"
  trivy image -q --severity CRITICAL --exit-code 1 --ignore-unfixed "$REPO:$TAG"
fi

echo "▶ push"
docker push -q "$REPO:$TAG" >/dev/null
DIGEST=$(docker buildx imagetools inspect "$REPO:$TAG" --format '{{json .Manifest.Digest}}' | tr -d '"')
echo "  $REPO@$DIGEST"

if [[ $SIGN == 1 ]]; then
  echo "▶ cosign sign (clave del pipeline, sin Rekor)"
  COSIGN_PASSWORD="" cosign sign --yes --key "$COSIGN_KEY" \
    --use-signing-config=false --tlog-upload=false \
    "$REPO@$DIGEST" 2>&1 | grep -v -i deprecat || true
fi

echo "▶ deploy/deployment.yaml → $REPO:$TAG@$DIGEST"
sed -i.bak -E "s#image: .*supply-chain-demo.*#image: $REPO:$TAG@$DIGEST#" deploy/deployment.yaml && rm deploy/deployment.yaml.bak
echo "✔ listo: haz commit y push de deploy/"

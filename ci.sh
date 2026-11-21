#!/usr/bin/env bash
# "Pipeline" de la demo: build, SBOM (Syft), escaneo (Grype), push, firma, SBOM firmado y deploy/.
#
#   ./ci.sh              todos los pasos, en orden (en local)
#   ./ci.sh <paso>       un solo paso: es lo que llama cada step de .github/workflows/ci.yml
#   ./ci.sh pasos        lista los pasos en orden
#
# SCAN=0, SIGN=0 o SBOM=0 desactivan pasos (SBOM=0 no adjunta el SBOM).
# La clave privada solo existe en el terminal de CI (o en el secreto de GitHub): COSIGN_KEY=ruta/cosign.key
#
# SINCRONÍA CON GITHUB ACTIONS: este script es la única fuente de la lógica.
# El workflow solo prepara el entorno (herramientas, login, clave) y llama a
# "./ci.sh <paso>" en el mismo orden que PASOS. Si añades, quitas o renombras
# un paso aquí, hazlo también en ci.yml; el primer step del workflow lo comprueba.
set -euo pipefail

REPO=${REPO:-docker.io/pabpereza/supply-chain-demo}
TAG=${TAG:-$(git rev-parse --short HEAD)}
SCAN=${SCAN:-1}
SIGN=${SIGN:-1}
SBOM=${SBOM:-1}
COSIGN_KEY=${COSIGN_KEY:-$HOME/.config/supply-chain-demo/cosign.key}

PASOS=(build sbom scan push sign attest deploy)

# El digest se lee del registry: cada paso puede ir en un proceso distinto
digest() {
  docker buildx imagetools inspect "$REPO:$TAG" --format '{{json .Manifest.Digest}}' | tr -d '"'
}

paso_build() {
  echo "▶ build $REPO:$TAG"
  docker build -q -t "$REPO:$TAG" app/
}

# El inventario primero: Grype escanea el SBOM y el mismo SBOM viaja firmado con la imagen
paso_sbom() {
  echo "▶ syft (SBOM CycloneDX) → sbom.cdx.json"
  SYFT_FILE_METADATA_SELECTION=none syft -q "$REPO:$TAG" -o cyclonedx-json=sbom.cdx.json
  echo "  $(jq '.components | length' sbom.cdx.json) componentes"
}

paso_scan() {
  [[ $SCAN == 1 ]] || { echo "▷ scan desactivado (SCAN=0)"; return; }
  echo "▶ grype (falla si hay CRITICAL con parche)"
  grype -q --fail-on critical --only-fixed sbom:sbom.cdx.json
}

paso_push() {
  echo "▶ push"
  docker push -q "$REPO:$TAG" >/dev/null
  echo "  $REPO@$(digest)"
}

paso_sign() {
  [[ $SIGN == 1 ]] || { echo "▷ firma desactivada (SIGN=0)"; return; }
  echo "▶ cosign sign (clave del pipeline, sin Rekor)"
  COSIGN_PASSWORD="" cosign sign --yes --key "$COSIGN_KEY" \
    --use-signing-config=false --tlog-upload=false \
    "$REPO@$(digest)" 2>&1 | grep -v -i deprecat || true
}

paso_attest() {
  [[ $SBOM == 1 ]] || { echo "▷ SBOM sin adjuntar (SBOM=0)"; return; }
  echo "▶ cosign attest (SBOM firmado y adjunto a la imagen)"
  COSIGN_PASSWORD="" cosign attest --yes --key "$COSIGN_KEY" --type cyclonedx \
    --predicate sbom.cdx.json --use-signing-config=false --tlog-upload=false \
    "$REPO@$(digest)" 2>&1 | grep -v -i -E 'deprecat|payload from|signing artifact' || true
}

paso_deploy() {
  local img="$REPO:$TAG@$(digest)"
  echo "▶ deploy/deployment.yaml → $img"
  sed -i.bak -E "s#image: .*supply-chain-demo.*#image: $img#" deploy/deployment.yaml && rm deploy/deployment.yaml.bak
}

case "${1:-all}" in
  all)
    for p in "${PASOS[@]}"; do "paso_$p"; done
    echo "✔ listo: haz commit y push de deploy/"
    ;;
  pasos)
    printf '%s\n' "${PASOS[@]}"
    ;;
  *)
    if [[ " ${PASOS[*]} " == *" $1 "* ]]; then "paso_$1"
    else echo "paso desconocido: $1 (pasos: ${PASOS[*]})" >&2; exit 1
    fi
    ;;
esac

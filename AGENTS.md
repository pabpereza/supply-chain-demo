# Notas para agentes

## ci.sh y GitHub Actions van siempre a la par

- `ci.sh` es la única fuente de la lógica del pipeline. `.github/workflows/ci.yml` solo prepara el entorno (herramientas, login, clave) y llama a `./ci.sh <paso>`.
- Cualquier cambio en un sentido se refleja en el otro en el mismo commit:
  - Cambiar lo que hace un paso → solo `ci.sh`.
  - Añadir, quitar, renombrar o reordenar un paso → `PASOS` en `ci.sh` y los steps de `ci.yml`.
  - Nueva variable (como `SCAN`, `SIGN`, `SBOM`) → `ci.sh`, `env` e `inputs` de `workflow_dispatch` en `ci.yml`.
  - Nueva herramienta o versión → el step "Instalar" de `ci.yml`, la tabla de versiones del `README.md` y `PRACTICA.md`.
  - Si alguien edita el workflow con lógica propia, se lleva a `ci.sh` y el step vuelve a ser `./ci.sh <paso>`.
- Comprobar antes de commitear:

```bash
diff <(./ci.sh pasos) <(grep -oE '\./ci\.sh [a-z]+$' .github/workflows/ci.yml | awk '{print $2}' | grep -v '^pasos$')
actionlint .github/workflows/ci.yml
```

## Otras reglas

- La clave privada de Cosign nunca entra en el repo (`*.key` está en `.gitignore`). En Actions va en el secreto `COSIGN_PRIVATE_KEY`.
- Las políticas de imágenes se aplican con `kubectl apply --server-side`.

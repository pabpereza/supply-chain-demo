# supply-chain-demo

Demo de la charla **"De `docker build` a producción sin que te cuelen nada: Kyverno, Cosign y Argo CD"** (Cloud Native Ecuador).

Un clúster local (kind) con Argo CD sincronizando `deploy/`. Paso a paso se endurece el camino de la imagen hasta producción:

1. **Guardarraíles** con una `ValidatingPolicy` de Kyverno en CEL: sin `latest`, sin `privileged`, `runAsNonRoot`, límites y solo imágenes de `docker.io/pabpereza`. Se escribe para Pods y Kyverno la extiende sola a Deployments, Jobs...
2. **Escaneo con Trivy** en el pipeline: si hay CVEs críticas no se publica
3. **El ataque**: con un token del registry filtrado se sube una imagen que cumple todas las reglas... y pasa
4. **Firma con Cosign** + `ImageValidatingPolicy`: solo se admite lo firmado por el pipeline y siempre por digest, que el pipeline fija en Git

## Estructura

| Ruta | Qué es |
|------|--------|
| `app/` | La aplicación legítima (nginx sin privilegios) |
| `attacker/` | La imagen del atacante |
| `deploy/` | Lo que despliega Argo CD |
| `policies/kyverno/guardarrailes.yaml` | Reglas básicas del Pod (CEL) |
| `policies/kyverno/require-signed.yaml` | Verificación de la firma y del digest |
| `argocd/` | La `Application` de Argo CD |
| `ci.sh` | El "pipeline" local: build, Trivy, push, firma y digest en `deploy/` |
| `attack.sh` | Sube la imagen del atacante con el tag que quieras |
| `cosign.pub` | Clave pública del pipeline (la privada nunca está en el repo) |

## Versiones probadas

Kubernetes 1.37 (kind 0.33), Kyverno 1.20, Argo CD 3.x, Cosign 3.1.4.

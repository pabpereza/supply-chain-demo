# supply-chain-demo

Demo de la charla **"De `docker build` a producción sin que te cuelen nada: políticas nativas, Kyverno y Argo CD"** (Cloud Native Ecuador).

Un clúster local (kind) con Argo CD sincronizando `deploy/`. Paso a paso se endurece el camino de la imagen hasta producción:

1. **Guardarraíles nativos** con `ValidatingAdmissionPolicy` (`policies/vap/`): sin `latest`, sin `privileged`, `runAsNonRoot` y límites
2. **Solo mi registry** (VAP) y escaneo con Trivy en el pipeline
3. **El ataque**: con un token del registry filtrado se sube una imagen que cumple todas las reglas... y VAP la deja pasar
4. **Firma con Cosign + Kyverno** (`policies/kyverno/`): solo se admite lo firmado por el pipeline, y el tag se fija a su digest

## Estructura

| Ruta | Qué es |
|------|--------|
| `app/` | La aplicación legítima (nginx sin privilegios) |
| `attacker/` | La imagen del atacante |
| `deploy/` | Lo que despliega Argo CD |
| `policies/vap/` | Políticas nativas (CEL) |
| `policies/kyverno/` | `ImageValidatingPolicy` que verifica la firma |
| `argocd/` | La `Application` de Argo CD |
| `ci.sh` | El "pipeline" local: build, Trivy, push, firma |
| `attack.sh` | Sube la imagen del atacante con el tag que quieras |
| `cosign.pub` | Clave pública del pipeline (la privada nunca está en el repo) |

## Versiones probadas

Kubernetes 1.37 (kind 0.33), Kyverno 1.20, Argo CD 3.x, Cosign 3.1.4.

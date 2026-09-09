# Pipeline SDD orquestado

Se sigue el workflow de `~/.config/opencode/AGENTS.md`. Resumen aplicado a este repo:

## 1) Especificación

- Specs Gherkin en español bajo `specs/<módulo>/*.feature`, con IDs `@S-REP-nn`
  (repostería) y `@S-AGL-nn` (agile).
- Módulos: `specs/reposteria/` (clientes, inventario, productos, producción,
  ventas, reportes) y `specs/agile/` (backlog, sprints, burndown, priorización,
  kanban/gates, gitflow).
- Contratos en `contracts/`: `contracts/reposteria.md`, `contracts/agile.md`,
  `contracts/gitflow.md`.

## 2) Clarificación

- Ronda `sdd-spec` / `sdd-contract` / `sdd-clarifier`, máx. 3 iteraciones.
- Sin convergencia → spike de código. Checkpoint con el usuario solo si hay
  ambigüedad sin resolver o conflicto con un contrato en uso.

## 3) Implementación

- TDD estricto, Gherkin primero (ejecutable), skills `caveman` + `ponytail`.
- Un `sdd-implementer` por tarea. Módulos compartidos: entra primero el de
  menor diff estimado; el que espera recibe otra tarea de la cola.
- Orden de tareas según `docs/06-roadmap-mvp.md`.

## 4) Loop de revisión

`sdd-qa` (BDD + mutación ≥80%, acotado al diff) → `sdd-style` (hasta 3 rechazos)
→ `sdd-architect` (árbitro, gana la simple).

## 5) Verificación y entrega

- Suite **completa** verde, no solo el diff, antes de entregar.
- Cada test documenta el ID de escenario Gherkin que cubre.
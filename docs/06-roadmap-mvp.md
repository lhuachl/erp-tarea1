# Roadmap MVP

Orden de construcción por WSJF (ver `docs/05-priorizacion.md`) reconciliado con
dependencias técnicas.

## Fases de construcción

1. **Backlog (historias)** — base del dominio ágil
2. **Sprints + daily snapshots** — el sprint y sus datos diarios
3. **Burndown + velocity** — el chart pedido, pieza central
4. **Priorización WSJF + diagramas** — Cost of Delay sobre el backlog
5. **Inventario / insumos** — fundación del ERP
6. **Productos y recetas (BOM)** — depende de materiales
7. **Clientes** — necesario para ventas
8. **Ventas / pedidos** — depende de productos y clientes
9. **Producción** — consume BOM e inventario
10. **Kanban + gates burocráticas** — estados no saltables y DoD
11. **GitFlow** — scripts de release, changelog, gates de ramas
12. **Reportes ERP + Dashboard** — métricas agregadas y resumen

## Pantallas del frontend

Login → Dashboard (métricas ERP + resumen sprint) → **Burndown** →
**Priorización (WSJF)** → Sprint Board (kanban) → Backlog → Planificación →
Daily → Velocity → Reportes → Releases (GitFlow) → Clientes → Insumos/Stock →
Productos/Recetas → Producción → Pedidos.

## Criterio de salida MVP

- Suite BDD completa verde (Gherkin en español ejecutable).
- Mutation score ≥ 80% en módulos del diff.
- SPA operativo de punta a punta contra Supabase.
- GitFlow operativo: feature → develop → release → main con changelog.
# Modelo de datos

Monoproyecto: existe un único workspace con clave `REP`.

## Dominio Repostería (ERP)

| Tabla | Campos clave | Notas |
|---|---|---|
| `clients` | nombre, teléfono, email, dirección, notas | |
| `materials` | nombre, unidad, stock, stock_min, costo_unit | insumos |
| `stock_movements` | material, tipo (entrada/salida/ajuste), cantidad, referencia, fecha | |
| `products` | nombre, descripción, precio, activo | |
| `recipe_lines` | product, material, cantidad | receta/BOM |
| `production_orders` | fecha, estado, líneas | |
| `production_orders_lines` | production_order, product, cantidad | |
| `orders` | client, fecha, estado (pendiente/en_producción/entregado), total | venta |
| `order_lines` | order, product, cantidad, precio_unit | |

Regla de negocio: la producción consume el BOM → genera movimientos de salida
de materiales (inventario). El costo unitario del producto se deriva del BOM.

## Dominio Ágil

| Tabla | Campos clave | Notas |
|---|---|---|
| `workspace` | nombre, clave (`REP`), repo_url | monoproyecto |
| `backlog_items` | título, descripción, prioridad, story_points, estado (backlog/listo/en_sprint/done), **campos CoD** | ver priorización |
| `sprint_tasks` | sprint, backlog_item, título, horas_estimadas, horas_restantes, estado (todo/in_progress/review/done), asignado_a, git_branch, git_pr | |
| `sprints` | nombre, objetivo, fecha_inicio, fecha_fin, estado (planning/activo/cerrado) | |
| `daily_snapshots` | sprint, fecha, puntos_restantes, horas_restantes | fuente del burndown |
| `sprint_reviews` | sprint, fecha, notas, velocidad lograda | retro/review |

### Priorización (WSJF / Cost of Delay) — campos en `backlog_items`

| Campo | Tipo | Notas |
|---|---|---|
| `cod_value` | int 1–13 | valor de negocio |
| `cod_time_criticality` | int 1–13 | criticidad temporal |
| `cod_risk_reduction` | int 1–13 | reducción de riesgo/oportunidad |
| `cod_duration` | int | points/días (job size) |
| `wsjf` | decimal | `(value + criticality + risk) ÷ duration`, calculado por servicio |
| `cod_profile` | enum | `expedite` / `fixed_date` / `standard` / `intangible` |

## Reglas de integridad

- Un `sprint_task` pertenece a un `sprint` y opcionalmente a un `backlog_item`.
- `daily_snapshots` solo existen para sprints en estado `activo`.
- `wsjf` es calculado (DOP), nunca escrito a mano.
- El avance de estado de `sprint_tasks` está gateado por el estado de git
  (rama → PR → merge), ver `docs/04-gitflow.md`.
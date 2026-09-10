# Contrato del módulo Backlog (historias de usuario)

Dominio: agile. Frontera del módulo con el resto del sistema y con clientes HTTP.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Sprint (**implementado** en la sección Sprint + daily snapshots): un BacklogItem en `en_sprint` lleva `sprint_id` (asignación a sprint). La transición `listo → en_sprint` requiere un `sprint_id` válido (ver [Dependencias](#dependencias)).

## Runner BDD y mutación (fijados por stack del repo)

- Runner BDD: `cucumber-rails` (features Gherkin en `features/`, ya declarado en `Gemfile` grupo `:test`).
- Herramienta de mutación: `mutant` + `mutant-rspec` (grupo `:development, :test` del `Gemfile`). Comando real (requiere `--usage opensource`):
  `RAILS_ENV=test bundle exec mutant run --usage opensource --include app --include config --require environment --use rspec "ClaseEnElDiff"`
- Los tests BDD se acotan a `features/` y se rastrean a escenarios `@S-AGL-nn` (ver [Escenarios](#escenarios-gherkin-que-ejercitan-este-contrato)).

## Endpoints de API (base `/api/v1`)

| Método | Ruta                     | Descripción                                             | Éxito |
|--------|--------------------------|---------------------------------------------------------|-------|
| GET    | `/api/v1/backlog_items`  | Lista de historias, ordenada por prioridad (alta > media > baja) y luego por `wsjf` desc. | 200 |
| POST   | `/api/v1/backlog_items`  | Crea una historia de usuario. `estado` inicial siempre `backlog`. | 201 |
| PATCH  | `/api/v1/backlog_items/:id` | Edita campos editables y/o transiciona `estado`. | 200 |

## Estructuras de datos

### BacklogItem (historia de usuario)

| Campo                    | Tipo     | Requerido | Default    | Lectura | Escritura |
|--------------------------|----------|-----------|------------|---------|-----------|
| `id`                     | integer  | —         | —          | sí      | no (solo lectura) |
| `titulo`                 | string   | sí        | —          | sí      | sí |
| `descripcion`            | string   | no        | `""`       | sí      | sí |
| `story_points`           | integer  | sí        | —          | sí      | sí |
| `prioridad`              | enum     | no        | `"media"`  | sí      | sí |
| `estado`                 | enum     | no        | `"backlog"`| sí      | sí (solo vía PATCH, con transición válida) |
| `cod_value`              | number   | no        | `0`        | sí      | sí |
| `cod_time_criticality`   | number   | no        | `0`        | sí      | sí |
| `cod_risk_reduction`     | number   | no        | `0`        | sí      | sí |
| `cod_duration`           | number   | no        | `0`        | sí      | sí |
| `wsjf`                   | number   | —         | calculado  | sí      | **no — calculado, nunca se recibe del cliente** |
| `cod_profile`            | string   | —         | calculado  | sí      | **no — calculado, nunca se recibe del cliente** |

Enums:

- `prioridad` ∈ `{ "alta", "media", "baja" }` — orden de prioridad: `alta` > `media` > `baja`.
- `estado` ∈ `{ "backlog", "listo", "en_sprint", "done" }`.

### Respuesta de listado — `GET /api/v1/backlog_items`

```json
{
  "data": [
    {
      "id": 1,
      "titulo": "Cobrar pedidos pendientes",
      "descripcion": "",
      "story_points": 3,
      "prioridad": "alta",
      "estado": "backlog",
      "cod_value": 8,
      "cod_time_criticality": 5,
      "cod_risk_reduction": 3,
      "cod_duration": 2,
      "wsjf": 8.0,
      "cod_profile": "standard"
    }
  ]
}
```

### Request de creación — `POST /api/v1/backlog_items`

```json
{
  "titulo": "Cobrar pedidos pendientes",
  "story_points": 3,
  "prioridad": "alta",
  "cod_value": 8,
  "cod_time_criticality": 5,
  "cod_risk_reduction": 3,
  "cod_duration": 2
}
```

Response: `201` con el `BacklogItem` creado (misma forma que el listado, `data` en singular).

### Request de edición/transición — `PATCH /api/v1/backlog_items/:id`

```json
{
  "titulo": "Cobrar pedidos pendientes (reparto)",
  "estado": "listo"
}
```

Response: `200` con el `BacklogItem` actualizado.

## Invariantes

1. **`wsjf` y `cod_profile` se calculan SIEMPRE en el servidor** a partir de `cod_value`, `cod_time_criticality`, `cod_risk_reduction` y `cod_duration`. Nunca se aceptan del cliente: enviarlos en POST/PATCH devuelve `422` (`readonly_field`).
2. `titulo` es obligatorio y no vacío.
3. `story_points` es un entero mayor a 0.
4. `prioridad` ∈ `{ "alta", "media", "baja" }`.
5. `estado` ∈ `{ "backlog", "listo", "en_sprint", "done" }` con **transición estricta sin saltos**: `backlog → listo → en_sprint → done`. No se permiten retrocesos ni saltos de estado.
6. `POST` no acepta `estado`: el estado inicial es siempre `backlog` (enviarlo devuelve `422`).
7. En `PATCH`, `estado` solo se valida contra el estado actual persistido; la historia debe existir (`404` si no).
8. El orden del listado es: `prioridad` (alta > media > baja) y, dentro de la misma prioridad, `wsjf` descendente.

## Errores

Códigos HTTP y shape de error estándar del proyecto (JSON API):

| Código HTTP | `code`                | Cuándo |
|-------------|-----------------------|--------|
| 400         | `malformed_request`   | JSON inválido o request malformado |
| 404         | `not_found`           | `:id` de historia inexistente |
| 422         | `validation_failed`   | `titulo` vacío, `story_points` no entero o ≤ 0, `prioridad`/`estado` fuera del enum |
| 422         | `invalid_transition`  | transición de `estado` inválida (salto, retroceso o destino inexistente) |
| 422         | `readonly_field`      | se envía `wsjf`, `cod_profile`, `id` o `estado` en POST |
| 422         | `readonly_field`      | se envía `wsjf` o `cod_profile` en PATCH |

Body de error (siempre la misma forma):

```json
{
  "errors": [
    {
      "status": "422",
      "code": "validation_failed",
      "title": "No se pudo procesar la solicitud",
      "detail": "story_points debe ser un entero mayor a 0",
      "source": { "pointer": "/story_points" }
    }
  ]
}
```

## Dependencias

- Este módulo **depende ahora del módulo Sprint** para la asignación: al transicionar `listo → en_sprint`, el PATCH debe incluir un `sprint_id` de un sprint existente (el item queda asignado a ese sprint). La validación de unicidad de sprint activo y de no vacío al activar vive en el módulo Sprint. Sin esta asignación, `en_sprint` sigue siendo solo una transición de estado.

## Escenarios Gherkin que ejercitan este contrato

Spec: `specs/agile/backlog.feature`

- `@S-AGL-01` — crear historia de usuario válida (estado inicial `backlog`, `wsjf` calculado).
- `@S-AGL-02` — crear historia inválida (`titulo` vacío, `story_points` ≤ 0, `prioridad` fuera de enum) → `422 validation_failed`.
- `@S-AGL-03` — transicionar `backlog → listo → en_sprint → done` en orden estricto.
- `@S-AGL-04` — transición inválida (salto/retroceso) → `422 invalid_transition`, estado intacto.
- `@S-AGL-05` — editar campos básicos y de Cost of Delay; `wsjf` recalculado y devuelto.
- `@S-AGL-06` — listar backlog ordenado por prioridad (alta > media > baja) y, dentro de la misma prioridad, por `wsjf` desc.

---

# Contrato del módulo Sprint + daily snapshots

Dominio: agile. Frontera del módulo con el resto del sistema y con clientes HTTP.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Backlog: su `BacklogItem` guarda `sprint_id` al transicionar a `en_sprint` (ver [Dependencias](#dependencias-1)).
- Módulo Burndown (planificado, **no implementado**): será consumidor de los `daily_snapshots`.

## Runner BDD y mutación

Los mismos fijados por el repo en la sección de Backlog (arriba): `cucumber-rails` para Gherkin y `mutant` + `mutant-rspec` para mutación.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                                      | Descripción                                                        | Éxito |
|--------|-------------------------------------------|--------------------------------------------------------------------|-------|
| GET    | `/api/v1/sprints`                         | Lista de sprints con su estado.                                    | 200 |
| GET    | `/api/v1/sprints/:id`                     | Obtiene un sprint por id.                                          | 200 |
| POST   | `/api/v1/sprints`                         | Crea un sprint. `estado` inicial siempre `planning`.               | 201 |
| PATCH  | `/api/v1/sprints/:id`                     | Edita `nombre`/`objetivo`/fechas y/o transiciona `estado`.         | 200 |
| POST   | `/api/v1/sprints/:sprint_id/daily_snapshots` | Registra el snapshot diario del sprint activo.                  | 201 |

## Estructuras de datos

### Sprint

| Campo         | Tipo     | Requerido | Default     | Lectura | Escritura |
|---------------|----------|-----------|-------------|---------|-----------|
| `id`          | integer  | —         | —           | sí      | no (solo lectura) |
| `nombre`      | string   | sí        | —           | sí      | sí |
| `objetivo`    | string   | no        | `""`        | sí      | sí |
| `fecha_inicio`| date     | sí        | —           | sí      | sí (solo en estado `planning`) |
| `fecha_fin`   | date     | sí        | —           | sí      | sí (solo en estado `planning`) |
| `estado`      | enum     | no        | `"planning"`| sí      | sí (solo vía PATCH, con transición válida) |

Enums:

- `estado` ∈ `{ "planning", "activo", "cerrado" }` — transición estricta sin saltos ni retrocesos: `planning → activo → cerrado`.

### DailySnapshot

| Campo              | Tipo    | Requerido | Default | Lectura | Escritura |
|--------------------|---------|-----------|---------|---------|-----------|
| `id`               | integer | —         | —       | sí      | no (solo lectura) |
| `sprint_id`        | integer | —         | —       | sí      | no (viene de la ruta `:sprint_id`) |
| `fecha`            | date    | sí        | —       | sí      | sí (en la creación) |
| `puntos_restantes` | integer | sí        | —       | sí      | sí (en la creación) |
| `horas_restantes`  | integer | sí        | —       | sí      | sí (en la creación) |

Nota: el snapshot es inmutable — solo se crea; un día ya registrado no se sobrescribe (`snapshot_duplicado`).

### Request de creación — `POST /api/v1/sprints`

```json
{
  "nombre": "Sprint 1",
  "objetivo": "Ordenar el flujo de cobro",
  "fecha_inicio": "2026-09-07",
  "fecha_fin": "2026-09-18"
}
```

Response: `201` con el `Sprint` creado (shape `{"data": {...Sprint}}`, misma forma JSON API que Backlog). `estado` devuelto: `"planning"`.

### Request de edición/transición — `PATCH /api/v1/sprints/:id`

```json
{
  "nombre": "Sprint 1 (cobro)",
  "estado": "activo"
}
```

Response: `200` con el `Sprint` actualizado.

### Request de snapshot — `POST /api/v1/sprints/:sprint_id/daily_snapshots`

```json
{
  "fecha": "2026-09-09",
  "puntos_restantes": 21,
  "horas_restantes": 40
}
```

Response: `201` con el `DailySnapshot` creado (shape `{"data": {...DailySnapshot}}`).

## Invariantes

1. **`nombre` es obligatorio y no vacío.**
2. `fecha_fin >= fecha_inicio` y ambas **de hoy en adelante**. Violación → `422 validation_failed`.
3. `estado` inicial siempre `planning` (`POST` no acepta `estado`).
4. `estado` ∈ `{ "planning", "activo", "cerrado" }` con **transición estricta sin saltos ni retrocesos**: `planning → activo → cerrado`. Violación → `422 invalid_transition`, estado persistido intacto.
5. **Unicidad del sprint activo**: solo un sprint `activo` a la vez en el workspace "REP". Activar un segundo → `422 sprint_activo_duplicado`.
6. **Regla de sprint no vacío**: activar exige al menos una `backlog_item` en estado `en_sprint` con `sprint_id` referenciando al sprint. Si no → `422 sprint_vacio`.
7. **Snapshot solo sobre sprint activo**: si el sprint no está `activo` → `422 sprint_no_activo`.
8. `fecha` del snapshot debe caer dentro del rango `[fecha_inicio, fecha_fin]` del sprint activo; `puntos_restantes` y `horas_restantes` enteros `>= 0`. Violación → `422 validation_failed`.
9. **Unicidad por (sprint, fecha)**: un snapshot por día del sprint; duplicado → `422 snapshot_duplicado` (el snapshot existente queda intacto).
10. El **cierre** solo se permite desde `activo`. Hoy el cierre no exige tareas sin `done`; ese bloqueo llega con el módulo Kanban (frontera futura).

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (ver arriba): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo.

Códigos nuevos de este módulo (los códigos `validation_failed`, `invalid_transition`, `not_found`, `malformed_request` del Backlog aplican igual aquí):

| Código HTTP | `code`                    | Cuándo |
|-------------|---------------------------|--------|
| 422         | `sprint_activo_duplicado` | se intenta activar un sprint cuando ya existe uno `activo` |
| 422         | `sprint_vacio`            | se intenta activar un sprint sin historias `en_sprint` asignadas |
| 422         | `sprint_no_activo`        | se intenta registrar un snapshot sobre un sprint no `activo` |
| 422         | `snapshot_duplicado`      | ya existe un snapshot para ese `(sprint, fecha)` |

## Dependencias

- **Frontera Backlog → Sprint**: el `BacklogItem` guarda `sprint_id` al transicionar a `en_sprint` (cubierto en `backlog.feature` `@S-AGL-03/04`). Sprint es **consumidor** de ese estado: solo lo verifica al activar (regla de sprint no vacío). Backlog no depende de Sprint.
- **Frontera Sprint → Burndown** (futuro): el módulo Burndown será consumidor de los `daily_snapshots` (`puntos_restantes`, `horas_restantes` por fecha) para construir el chart.
- **Frontera futura Kanban**: el cierre del sprint aún no exige tareas sin `done`; se limitará cuando llegue ese módulo.

## Escenarios Gherkin que ejercitan este contrato

Spec: `specs/agile/sprints.feature`

- `@S-AGL-10` — crear sprint válido → `201`, `estado` inicial `planning`.
- `@S-AGL-11` — crear sprint inválido (`nombre` vacío, `fecha_fin < fecha_inicio`, fechas pasadas) → `422 validation_failed`, nada creado.
- `@S-AGL-12` — ciclo de vida completo en orden estricto: `planning → activo → cerrado` vía PATCH.
- `@S-AGL-13` — transiciones inválidas (salto `planning → cerrado`, retrocesos `activo → planning`, `cerrado → activo`) → `422 invalid_transition`, estado intacto.
- `@S-AGL-14` — activar un segundo sprint con otro ya `activo` → `422 sprint_activo_duplicado`.
- `@S-AGL-15` — activar sprint sin historias asignadas → `422 sprint_vacio`.
- `@S-AGL-16` — registrar daily snapshot válido sobre sprint `activo` → `201`.
- `@S-AGL-17` — snapshot inválido: sprint no `activo` (`sprint_no_activo`), `fecha` fuera del rango, enteros negativos → `422 validation_failed`.
- `@S-AGL-18` — segundo snapshot el mismo día del mismo sprint → `422 snapshot_duplicado`, el existente intacto.
- `@S-AGL-19` — listar sprints con su estado y obtener uno por id → `200`.
# Contrato del módulo Backlog (historias de usuario)

Dominio: agile. Frontera del módulo con el resto del sistema y con clientes HTTP.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Sprint (**implementado** en la sección Sprint + daily snapshots): un BacklogItem en `en_sprint` lleva `sprint_id` (asignación a sprint). La transición `listo → en_sprint` requiere un `sprint_id` válido (ver [Dependencias](#dependencias)).

## Runner BDD y mutación (fijados por stack del repo)

- Runner BDD: `cucumber-rails` (features Gherkin en `features/`, ya declarado en `Gemfile` grupo `:test`).
- Herramienta de mutación: `mutant` + `mutant-rspec` (grupo `:development, :test` del `Gemfile`). Comando real (requiere `--usage opensource`):
  `RAILS_ENV=test bundle exec mutant run --usage opensource --include app --include config --require environment --use rspec -t 90 "ClaseEnElDiff"`

  `-t 90` es obligatorio: la suite pega contra Supabase remoto y supera el timeout
  por defecto (5s), lo que haría contar timeouts como kills y falsear el score.
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
2. `fecha_fin >= fecha_inicio` y `fecha_fin >= hoy`. NO se exige `fecha_inicio >= hoy` (un sprint puede haber empezado). Violación → `422 validation_failed`.
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

---

# Contrato del módulo Priorización (WSJF / Cost of Delay + diagramas)

Dominio: agile. Frontera del módulo con el resto del sistema y con clientes HTTP. Módulo de **solo lectura**: no crea ni modifica `BacklogItem`.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos que alimentan los diagramas (ranking, matriz de burbujas, perfil CoD).
- Módulo Backlog: **dueño** de los datos. Priorización consume `BacklogItem` en solo lectura; nunca escribe ni transiciona estados.

## Runner BDD y mutación

Los mismos fijados por el repo en la sección de Backlog (arriba): `cucumber-rails` para Gherkin y `mutant` + `mutant-rspec` para mutación.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                                | Descripción                                                                 | Éxito |
|--------|-------------------------------------|-----------------------------------------------------------------------------|-------|
| GET    | `/api/v1/prioritization/ranking`    | Ranking WSJF de historias. Query opcional `?estado=` (`backlog`/`listo`/`en_sprint`/`done`). | 200 |
| GET    | `/api/v1/prioritization/matriz`     | Puntos de la matriz de burbujas (cuadrante CoD vs duración).                | 200 |
| GET    | `/api/v1/prioritization/perfil`     | Historias agrupadas en los 4 cubos de `cod_profile`.                        | 200 |

Los tres son `GET` de **solo lectura**. No existen POST/PATCH/DELETE en este módulo.

## Estructuras de datos

### RankingEntry (entrada del ranking)

| Campo                  | Tipo    | Origen                | Lectura | Escritura |
|------------------------|---------|-----------------------|---------|-----------|
| `id`                   | integer | `BacklogItem.id`      | sí      | no (solo lectura) |
| `titulo`               | string  | `BacklogItem.titulo`  | sí      | no (solo lectura) |
| `prioridad`            | enum    | `BacklogItem.prioridad` | sí    | no (solo lectura) |
| `estado`               | enum    | `BacklogItem.estado`  | sí      | no (solo lectura) |
| `cod_value`            | number  | `BacklogItem.cod_value` | sí    | no (solo lectura) |
| `cod_time_criticality` | number  | `BacklogItem.cod_time_criticality` | sí | no (solo lectura) |
| `cod_risk_reduction`   | number  | `BacklogItem.cod_risk_reduction` | sí | no (solo lectura) |
| `cod_duration`         | number  | `BacklogItem.cod_duration` | sí   | no (solo lectura) |
| `wsjf`                 | number  | **calculado en servidor** | sí  | **no — calculado, nunca se recibe del cliente** |
| `cod_profile`          | string  | **calculado en servidor** | sí  | **no — calculado, nunca se recibe del cliente** |

`RankingEntry` es una **proyección de lectura** de `BacklogItem` (mismos enums `prioridad` y `estado` definidos en el contrato de Backlog). No agrega campos editables.

### MatrizPoint (punto de la matriz de burbujas)

| Campo         | Tipo    | Origen / cálculo                         |
|---------------|---------|------------------------------------------|
| `titulo`      | string  | `BacklogItem.titulo`                     |
| `x`           | number  | `cod_duration` (duración/complejidad)    |
| `y`           | number  | `cod_value + cod_time_criticality + cod_risk_reduction` (CoD total) |
| `tamano`      | number  | `wsjf` (tamaño de la burbuja)            |
| `cod_profile` | string  | **calculado en servidor**                |

### Perfil CoD

Agrupación por `cod_profile` en cuatro cubos fijos. Cada cubo contiene `RankingEntry[]`, con el mismo orden del ranking.

- `expedite` — `wsjf >= 20`.
- `fixed_date` — `cod_time_criticality >= 8` (y no `expedite`).
- `standard` — `wsjf >= 5` (y no `fixed_date`/`expedite`).
- `intangible` — el resto, **incluye siempre `cod_duration = 0`**.

Regla de `cod_profile` ya vigente y calculada en `BacklogItem`; este módulo solo la consume.

### Respuesta — `GET /api/v1/prioritization/ranking`

```json
{
  "data": [
    {
      "id": 1,
      "titulo": "Torta de cumpleaños",
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

### Respuesta — `GET /api/v1/prioritization/ranking?estado=done`

```json
{
  "data": [
    {
      "id": 2,
      "titulo": "Cobrar pedidos pendientes",
      "prioridad": "media",
      "estado": "done",
      "cod_value": 4,
      "cod_time_criticality": 3,
      "cod_risk_reduction": 5,
      "cod_duration": 2,
      "wsjf": 6.0,
      "cod_profile": "standard"
    }
  ]
}
```

### Respuesta — `GET /api/v1/prioritization/matriz`

```json
{
  "data": [
    {
      "titulo": "Torta de cumpleaños",
      "x": 2,
      "y": 16,
      "tamano": 8.0,
      "cod_profile": "standard"
    },
    {
      "titulo": "Reparto del turno tarde",
      "x": 1,
      "y": 30,
      "tamano": 30.0,
      "cod_profile": "expedite"
    }
  ]
}
```

### Respuesta — `GET /api/v1/prioritization/perfil`

```json
{
  "data": {
    "expedite": [
      { "id": 1, "titulo": "Torta de cumpleaños", "cod_profile": "expedite", "wsjf": 30.0 }
    ],
    "fixed_date": [
      { "id": 2, "titulo": "Cobrar pedidos pendientes", "cod_profile": "fixed_date", "wsjf": 2.75 }
    ],
    "standard": [
      { "id": 3, "titulo": "Reparto del turno tarde", "cod_profile": "standard", "wsjf": 6.0 }
    ],
    "intangible": [
      { "id": 4, "titulo": "Ajustar receta", "cod_profile": "intangible", "wsjf": 0.3 }
    ]
  }
}
```

> Los objetos de ejemplo se abrevan a los campos ilustrativos; cada elemento del cubo es un `RankingEntry` completo.

## Invariantes

1. **`wsjf` se calcula SIEMPRE en el servidor**: `wsjf = (cod_value + cod_time_criticality + cod_risk_reduction) / cod_duration`. El cliente nunca lo provee. Los endpoints son de solo lectura, por lo que un parámetro `wsjf` en la query se **ignora** (el valor devuelto es el calculado).
2. **`cod_duration = 0`**: `wsjf = 0` (sin división por cero), `cod_profile = "intangible"` y la historia va **al final del ranking** (con `wsjf` 0 queda última por el criterio de orden).
3. **`cod_profile`** ∈ `{ "expedite", "fixed_date", "standard", "intangible" }` con la regla de prelación del contrato de Backlog.
4. **Orden del ranking**: `wsjf` descendente; empate → `prioridad` (`alta` > `media` > `baja`); nuevo empate → `id` ascendente.
5. **Filtro opcional `?estado=`**: si viene, el ranking solo incluye historias con ese `estado`. Si se omite, incluye todas. `estado` fuera del enum → `422 validation_failed`.
6. **La matriz incluye TODAS las historias, sin filtrar por estado** (incluye `backlog`, `listo`, `en_sprint`, `done`).
7. **El perfil incluye todas las historias** (sin filtro de estado) y cubre los 4 cubos; un cubo sin historias se devuelve como arreglo vacío.
8. Los tres endpoints son de **solo lectura**: no mutan `BacklogItem` ni su estado.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (arriba): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo. Este módulo no define códigos nuevos; aplican `malformed_request` (JSON/query malformada) y `validation_failed` (`estado` fuera del enum).

## Dependencias

- **Frontera Priorización → Backlog**: Priorización consume `BacklogItem` en **solo lectura** (proyección `RankingEntry`, `MatrizPoint`, cubos de perfil). No escribe ni transiciona estados; no crea nuevas dependencias en Backlog.

## Escenarios Gherkin que ejercitan este contrato

Spec: `specs/agile/priorizacion.feature`

- `@S-AGL-20` — ranking ordenado por `wsjf` desc, desempate por `prioridad` (alta > media > baja) e `id` asc; la entrada incluye los componentes CoD.
- `@S-AGL-21` — filtro opcional `?estado=` (esquema: `done`, `backlog`, `en_sprint`) devuelve solo las historias de ese estado.
- `@S-AGL-22` — historia con `cod_duration = 0` → `wsjf 0`, `cod_profile "intangible"` y al final del ranking.
- `@S-AGL-23` — matriz de cuadrante: `x = cod_duration`, `y =` CoD total, `tamano = wsjf`, con todas las historias sin filtrar por estado.
- `@S-AGL-24` — perfil CoD agrupado en `expedite`, `fixed_date`, `standard` e `intangible`.
- `@S-AGL-25` — el ranking es de solo lectura: un `wsjf` inyectado por el cliente (`999`) se ignora y se devuelve el calculado (`8.0`).

---

# Contrato del módulo Burndown + velocity

Dominio: agile. Frontera del módulo con el resto del sistema y con clientes HTTP. Módulo de **solo lectura**: no crea ni modifica `Sprint`, `DailySnapshot` ni `BacklogItem`.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos que renderizan el chart y el histórico de velocity.
- Módulo Sprint: **dueño** de `Sprint` y `DailySnapshot`. Burndown los consume en solo lectura.
- Módulo Backlog: **dueño** de `BacklogItem`. Burndown consume `story_points`, `estado`, `sprint_id` y el nuevo `sprint_assigned_at` (ver [Dependencias](#dependencias-3)).

## Runner BDD y mutación

Los mismos fijados por el repo en la sección de Backlog (arriba): `cucumber-rails` para Gherkin y `mutant` + `mutant-rspec` para mutación.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                            | Descripción                                                              | Éxito |
|--------|---------------------------------|--------------------------------------------------------------------------|-------|
| GET    | `/api/v1/sprints/:id/burndown`  | Burndown del sprint: ideal, real y huecos. Solo sprint `activo` o `cerrado`. | 200 |
| GET    | `/api/v1/velocity`              | Velocity histórica de los sprints `cerrados`.                            | 200 |

Ambos son `GET` de **solo lectura**. No existen POST/PATCH/DELETE en este módulo.

## Estructuras de datos

### Burndown

| Campo          | Tipo                | Origen / cálculo |
|----------------|---------------------|------------------|
| `total_puntos` | integer             | Σ `story_points` de las historias con `sprint_id = :id`, en cualquier estado (`done` incluido). |
| `fecha_inicio` | date                | `Sprint.fecha_inicio`. |
| `fecha_fin`    | date                | `Sprint.fecha_fin`. |
| `ideal`        | `IdealPoint[]`      | Línea ideal (ver invariantes 2–3), ordenada por `fecha` asc. |
| `real`         | `RealSnapshot[]`    | `DailySnapshot` del sprint, ordenados por `fecha` asc. |
| `huecos`       | `date[]`            | Fechas del rango sin snapshot, orden asc. |

- `IdealPoint = { fecha: date, restante: number }`.
- `RealSnapshot = { fecha: date, puntos_restantes: integer }`.
- `huecos` es un arreglo de fechas (`[fecha]`); el comentario inline de `burndown.feature` lo bosqueja como `[{fecha}]`, pero el shape de contrato es la lista de fechas.

### Respuesta — `GET /api/v1/sprints/:id/burndown`

```json
{
  "data": {
    "total_puntos": 6,
    "fecha_inicio": "2026-09-04",
    "fecha_fin": "2026-09-10",
    "ideal": [
      { "fecha": "2026-09-04", "restante": 6 },
      { "fecha": "2026-09-10", "restante": 0 }
    ],
    "real": [
      { "fecha": "2026-09-04", "puntos_restantes": 6 },
      { "fecha": "2026-09-07", "puntos_restantes": 4 }
    ],
    "huecos": [ "2026-09-05", "2026-09-06" ]
  }
}
```

### Velocity

| Campo    | Tipo            | Origen / cálculo |
|----------|-----------------|------------------|
| `sprints`| `VelocitySprint[]` | Un elemento por sprint `cerrado`, ordenado por `fecha_fin` asc. |
| `promedio` | number        | Media aritmética de `puntos_completados` (ver invariante 9). |
| `tendencia` | enum         | `{ "sube", "baja", "estable" }` (ver invariante 10). |

- `VelocitySprint = { nombre: string, puntos_comprometidos: integer, puntos_completados: integer }`.

### Respuesta — `GET /api/v1/velocity`

```json
{
  "data": {
    "sprints": [
      { "nombre": "Sprint 1", "puntos_comprometidos": 6, "puntos_completados": 6 }
    ],
    "promedio": 7.0,
    "tendencia": "sube"
  }
}
```

## Invariantes

1. **`total_puntos`** = Σ `story_points` de las historias del sprint, en cualquier estado (`done` incluido). Un total `0` es válido y no rompe el cálculo.
2. **`ideal` son `N + 1` entradas**, una por cada fecha de `[fecha_inicio, fecha_fin]` inclusive, orden asc, con `N = (fecha_fin - fecha_inicio)` en días. `restante(i) = total_puntos * (N - i) / N`, con `i = 0..N`: `total_puntos` en `fecha_inicio` y `0` en `fecha_fin`.
3. **Sin división por cero**: si `total_puntos = 0` o `N = 0`, `restante = 0` en todas las fechas del rango.
4. **Scope change**: si una historia se asigna al sprint con fecha (`sprint_assigned_at`) posterior a `fecha_inicio`, el ideal se **recalcula desde esa fecha de asignación** con el nuevo `total_puntos` acumulado. El tramo anterior conserva la línea del total previo sobre la ventana completa del sprint y se admite el salto vertical en el corte. Cada reasignación posterior reinicia el tramo con el total vigente.
5. **`real`** = `DailySnapshot.puntos_restantes` del sprint ordenados por `fecha` asc. No incluye fechas sin snapshot.
6. **`huecos`** = fechas de `[fecha_inicio, fecha_fin]` sin snapshot, orden asc; incluye días futuros aún sin snapshot.
7. **Acceso al burndown**: solo sprint `activo` o `cerrado`. Un sprint en `planning` → `422 sprint_no_iniciado`; un `:id` inexistente → `404 not_found` (ver [Errores](#errores-3)).
8. **`sprints` de velocity**: solo sprints `cerrado`, ordenados por `fecha_fin` asc (el último es el de mayor `fecha_fin`).
9. `puntos_comprometidos` = Σ `story_points` de las historias del sprint, en cualquier estado. `puntos_completados` = Σ `story_points` de las historias en estado `done`.
10. `promedio` = media aritmética de `puntos_completados` de los sprints cerrados. `tendencia` compara el **último sprint cerrado** contra `promedio`: último > promedio → `"sube"`; último < promedio → `"baja"`; último = promedio → `"estable"`.
11. **Sin sprints cerrados**: `sprints = []`, `promedio = 0`, `tendencia = "estable"` (no hay error).
12. Los dos endpoints son de **solo lectura**: no mutan `Sprint`, `DailySnapshot` ni `BacklogItem`.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (arriba): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo. Aplican `malformed_request` y `not_found` del contrato de Backlog; este módulo agrega un único código:

| Código HTTP | `code`                | Cuándo |
|-------------|-----------------------|--------|
| 404         | `not_found`           | `:id` de sprint inexistente en el burndown |
| 422         | `sprint_no_iniciado`  | se pide el burndown de un sprint en estado `planning` |

## Dependencias

- **Frontera Burndown → Sprint** (solo lectura): `Sprint.fecha_inicio`, `fecha_fin`, `estado` y, en velocity, `nombre`. Sprint no depende de Burndown.
- **Frontera Burndown → DailySnapshot** (solo lectura): `fecha`, `puntos_restantes`. El snapshot inmutable sigue siendo propiedad del módulo Sprint.
- **Frontera Burndown → Backlog** (solo lectura): `BacklogItem.story_points`, `estado`, `sprint_id` y `sprint_assigned_at`. Burndown no escribe ni transiciona estados.
- **Campo nuevo `sprint_assigned_at` (datetime) en `BacklogItem`** — frontera con Backlog y **deuda de implementación**:
  - Requerido para el scope change (invariante 4); sin él no se puede recalcular el ideal.
  - Se setea al asignar `sprint_id` (transición `listo → en_sprint`), de forma atómica con esa asignación. Nulo hasta la primera asignación.
  - La sección Backlog de este documento aún no lo lista; Backlog debe incorporarlo (migración) y **backfillear** las filas existentes con `sprint_id` antes de habilitar el scope change.
  - El comentario inline de `burndown.feature` lo llama `agregado_en`; el nombre fijado por contrato es `sprint_assigned_at`.

## Escenarios Gherkin que ejercitan este contrato

Spec: `specs/agile/burndown.feature`

- `@S-AGL-30` — burndown de sprint `activo`: `total_puntos`, rango, `ideal` lineal, `real` desde snapshots y `huecos` de los días sin snapshot.
- `@S-AGL-31` — el burndown también está disponible para un sprint `cerrado`.
- `@S-AGL-32` — esquema de acceso: sprint `planning` → `422 sprint_no_iniciado`; sprint inexistente → `404 not_found`.
- `@S-AGL-33` — scope change: historia agregada tras iniciar el sprint → `total_puntos` nuevo y `ideal` recalculado desde la fecha de asignación.
- `@S-AGL-34` — sprint con `total_puntos 0` → `ideal` en 0 sin romper el burndown.
- `@S-AGL-35` — velocity de sprints cerrados con `puntos_comprometidos`/`puntos_completados`, `promedio` y `tendencia "sube"`.
- `@S-AGL-36` — esquema de `tendencia` contra el `promedio`: `sube`, `baja` y `estable`.
- `@S-AGL-37` — sin sprints cerrados: `sprints = []`, `promedio = 0`, `tendencia = "estable"`.
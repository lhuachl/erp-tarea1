# Contrato del módulo Backlog (historias de usuario)

Dominio: agile. Frontera del módulo con el resto del sistema y con clientes HTTP.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Sprint (planificado, **no implementado**): consumirá historias en estado `en_sprint`. Hoy este módulo NO depende de sprints (ver [Dependencias](#dependencias)).

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

- Este módulo **NO depende de sprints aún**: el estado `en_sprint` se valida únicamente como transición permitida desde `listo`, **sin FK** ni verificación contra el módulo Sprint. El módulo Sprint es un consumidor planificado, no una dependencia de Backlog.

## Escenarios Gherkin que ejercitan este contrato

Spec: `specs/agile/backlog.feature`

- `@S-AGL-01` — crear historia de usuario válida (estado inicial `backlog`, `wsjf` calculado).
- `@S-AGL-02` — crear historia inválida (`titulo` vacío, `story_points` ≤ 0, `prioridad` fuera de enum) → `422 validation_failed`.
- `@S-AGL-03` — transicionar `backlog → listo → en_sprint → done` en orden estricto.
- `@S-AGL-04` — transición inválida (salto/retroceso) → `422 invalid_transition`, estado intacto.
- `@S-AGL-05` — editar campos básicos y de Cost of Delay; `wsjf` recalculado y devuelto.
- `@S-AGL-06` — listar backlog ordenado por prioridad (alta > media > baja) y, dentro de la misma prioridad, por `wsjf` desc.
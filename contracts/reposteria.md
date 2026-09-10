# Contrato del módulo Inventario / insumos

Dominio: repostería. Frontera del módulo con el resto del sistema y con clientes HTTP.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Recetas / Órdenes de producción (**planificado, no implementado**): consumirá insumos registrando movimientos de tipo `salida` (consumo de materia prima). El inventario no conoce de recetas ni de productos; solo recibe movimientos.
- Módulo Compras / Proveedores (**futuro, no implementado**): registrará movimientos de tipo `entrada` con `referencia` de compra.

## Runner BDD y mutación (fijados por stack del repo)

- Runner BDD: `cucumber-rails` (features Gherkin en `features/`, ya declarado en `Gemfile` grupo `:test`).
- Herramienta de mutación: `mutant` + `mutant-rspec` (grupo `:development, :test` del `Gemfile`). Comando real (requiere `--usage opensource`):
  `RAILS_ENV=test bundle exec mutant run --usage opensource --include app --include config --require environment --use rspec -t 90 "ClaseEnElDiff"` (`-t 90` obligatorio por latencia de Supabase remoto)
- Los tests BDD se acotan a `features/` y se rastrean a escenarios `@S-REP-nn` (ver [Escenarios](#escenarios-gherkin-que-ejercitan-este-contrato)).

## Endpoints de API (base `/api/v1`)

| Método | Ruta                                        | Descripción                                                                    | Éxito |
|--------|---------------------------------------------|--------------------------------------------------------------------------------|-------|
| POST   | `/api/v1/materials`                         | Crea un insumo.                                                                | 201 |
| GET    | `/api/v1/materials`                         | Lista de insumos. Con `?solo_criticos=true` devuelve solo los críticos.        | 200 |
| GET    | `/api/v1/materials/:id`                     | Obtiene un insumo por id.                                                      | 200 |
| PATCH  | `/api/v1/materials/:id`                     | Edita campos editables (`nombre`, `unidad`, `stock_min`, `costo_unitario`).    | 200 |
| POST   | `/api/v1/materials/:id/stock_movements`     | Registra un movimiento (`entrada` / `salida` / `ajuste`) y actualiza el stock. | 201 |

## Estructuras de datos

### Material (insumo)

| Campo            | Tipo    | Requerido | Default | Lectura | Escritura |
|------------------|---------|-----------|---------|---------|-----------|
| `id`             | integer | —         | —       | sí      | no (solo lectura) |
| `nombre`         | string  | sí        | —       | sí      | sí (POST y PATCH) |
| `unidad`         | enum    | sí        | —       | sí      | sí (POST y PATCH) |
| `stock_actual`   | number  | no        | `0`     | sí      | **no — solo vía movimientos de stock** |
| `stock_min`      | number  | no        | `0`     | sí      | sí (POST y PATCH) |
| `costo_unitario` | number  | no        | `0`     | sí      | sí (POST y PATCH) |
| `critico`        | boolean | —         | calculado | sí    | no (solo lectura) |

Enums:

- `unidad` ∈ `{ "kg", "g", "l", "ml", "unidad" }`.

Nota: `critico` es derivado (`stock_actual <= stock_min`); no se recibe del cliente.

### StockMovement (movimiento de stock)

| Campo        | Tipo    | Requerido | Default | Lectura | Escritura |
|--------------|---------|-----------|---------|---------|-----------|
| `id`         | integer | —         | —       | sí      | no (solo lectura) |
| `material_id`| integer | —         | —       | sí      | no (viene de la ruta `:id`) |
| `tipo`       | enum    | sí        | —       | sí      | sí (en la creación) |
| `cantidad`   | number  | sí        | —       | sí      | sí (en la creación) |
| `referencia` | string  | no        | `nil`   | sí      | sí (en la creación) |

Enums:

- `tipo` ∈ `{ "entrada", "salida", "ajuste" }`.

Nota: el movimiento es inmutable — solo se crea; no se edita ni se borra.

### Request de creación — `POST /api/v1/materials`

```json
{
  "nombre": "Harina",
  "unidad": "kg",
  "stock_actual": 10,
  "stock_min": 2,
  "costo_unitario": 3.5
}
```

Response: `201` con el `Material` creado (shape JSON API `{"data": {...Material}}`).

### Request de movimiento — `POST /api/v1/materials/:id/stock_movements`

```json
{
  "tipo": "entrada",
  "cantidad": 5,
  "referencia": "compra de harina"
}
```

Response: `201` con el `StockMovement` creado (shape `{"data": {...StockMovement}}`).

### Request de edición — `PATCH /api/v1/materials/:id`

```json
{
  "nombre": "Harina 000",
  "unidad": "g",
  "stock_min": 500,
  "costo_unitario": 4.0
}
```

Response: `200` con el `Material` actualizado. `stock_actual` nunca cambia por esta vía.

### Listado — `GET /api/v1/materials` (y `?solo_criticos=true`)

```json
{
  "data": [
    {
      "id": 1,
      "nombre": "Harina",
      "unidad": "kg",
      "stock_actual": 2,
      "stock_min": 2,
      "costo_unitario": 3.5,
      "critico": true
    }
  ]
}
```

## Invariantes

1. **`nombre` es obligatorio y no vacío**, y **único** en el workspace. Duplicado → `422 nombre_duplicado`.
2. `unidad` ∈ `{ "kg", "g", "l", "ml", "unidad" }`. Fuera del enum → `422 validation_failed`.
3. `stock_actual` `>= 0`, `stock_min` `>= 0` y `costo_unitario` `>= 0`. Violación → `422 validation_failed`.
4. `cantidad > 0` en todo movimiento. Violación → `422 validation_failed` y no se registra el movimiento.
5. `tipo` ∈ `{ "entrada", "salida", "ajuste" }`. Fuera del enum → `422 validation_failed` y no se registra el movimiento.
6. **Efecto de cada movimiento sobre `stock_actual`**:
   - `entrada`: `stock_actual += cantidad`.
   - `salida`: `stock_actual -= cantidad`; si el resultado sería negativo → `422 stock_insuficiente`, sin registrar el movimiento y con el stock intacto.
   - `ajuste`: `stock_actual = cantidad` (la cantidad representa el stock nuevo).
7. **Atomicidad**: el stock del material y el movimiento se persisten juntos o no se persiste ninguno. Ningún error de validación deja stock modificado ni movimiento registrado.
8. **`stock_actual` es de solo lectura por API**: `POST /materials` y `PATCH /materials/:id` que lo incluyan → `422 readonly_field`; el stock queda intacto. Solo se modifica registrando movimientos.
9. **Crítico**: un insumo es crítico si `stock_actual <= stock_min`. `GET /api/v1/materials?solo_criticos=true` devuelve exactamente esos insumos (el caso `<=` incluye el límite).
10. `GET /api/v1/materials/:id` sobre un id inexistente → `404 not_found`.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (`contracts/agile.md`, sección Errores): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo.

Códigos de este módulo:

| Código HTTP | `code`               | Cuándo |
|-------------|----------------------|--------|
| 422         | `validation_failed`  | `nombre` vacío; `unidad`/`tipo` fuera de enum; valores negativos; `cantidad <= 0` |
| 422         | `nombre_duplicado`   | ya existe un material con ese `nombre` |
| 422         | `stock_insuficiente` | una `salida` dejaría `stock_actual` negativo |
| 422         | `readonly_field`     | se envía `stock_actual` en `POST`/`PATCH` (o `critico`/`id`) |
| 404         | `not_found`          | `:id` de material inexistente |

Los códigos `malformed_request` (400) del contrato de Backlog aplican igual aquí.

## Dependencias

- **Frontera Inventario → Recetas / Producción** (futuro, `specs/reposteria`): las recetas/órdenes de producción consumirán insumos registrando movimientos de tipo `salida`. El inventario no conoce de recetas; la relación es unidireccional (quien produce llama a `POST /materials/:id/stock_movements`).
- **Frontera Inventario → Compras/Proveedores** (futuro): entradas de mercadería vía movimientos `entrada` con `referencia`.
- Este contrato **no depende** de ningún otro módulo del sistema.

## Escenarios Gherkin que ejercitan este contrato

Spec: `specs/reposteria/inventario.feature`

- `@S-REP-01` — crear insumo válido → `201` con los campos devueltos.
- `@S-REP-02` — creación inválida (`nombre` vacío, `unidad` fuera de enum, `stock_actual`/`stock_min`/`costo_unitario` negativos) → `422 validation_failed`, nada creado.
- `@S-REP-03` — crear insumo con `nombre` ya existente → `422 nombre_duplicado`, sin duplicado.
- `@S-REP-04` — registrar movimiento actualiza el stock de forma atómica: `entrada` suma (15), `salida` resta (6), `ajuste` fija (7).
- `@S-REP-05` — `salida` que dejaría stock negativo → `422 stock_insuficiente`, stock intacto, sin movimiento.
- `@S-REP-06` — movimiento inválido (`cantidad <= 0`, `tipo` fuera de enum) → `422 validation_failed`, stock intacto, sin movimiento.
- `@S-REP-07` — `GET /materials?solo_criticos=true` devuelve solo los insumos con `stock_actual <= stock_min`.
- `@S-REP-08` — `PATCH` edita `nombre`/`unidad`/`stock_min`/`costo_unitario` y conserva `stock_actual`.
- `@S-REP-09` — `PATCH` con `stock_actual` → `422 readonly_field`, stock intacto.
- `@S-REP-10` — listar insumos y obtener uno por id → `200` (más `404 not_found` vía [invariante 10](#invariantes)).

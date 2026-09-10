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
| `stock_actual`   | number  | no        | `0`     | sí      | sí en `POST` (stock inicial); **no en `PATCH`** (solo vía movimientos) |
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
8. **`stock_actual`**: se acepta en `POST /materials` como stock inicial (si no viene, default `0`). En `PATCH /materials/:id` es de solo lectura → `422 readonly_field` y el stock queda intacto; a partir de ahí solo se modifica registrando movimientos.
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
| 422         | `readonly_field`     | se envía `stock_actual` en `PATCH` (o `critico`/`id`) |
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

---

# Contrato del módulo Clientes

Dominio: repostería. Frontera del módulo con el resto del sistema y con clientes HTTP.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Ventas / Pedidos (**futuro, no implementado**): asociará pedidos a clientes. Mientras la asociación no exista, el guard de borrado permanece dormido (ver [Invariantes](#invariantes-1), punto 7). Clientes no conoce pedidos; la relación es unidireccional.

## Runner BDD y mutación (fijados por stack del repo)

Mismos que el módulo Inventario en este archivo: runner `cucumber-rails` y mutación `mutant` + `mutant-rspec`. Ver [Runner BDD y mutación](#runner-bdd-y-mutación-fijados-por-stack-del-repo). Los tests BDD se acotan a `features/` y se rastrean a escenarios `@S-REP-nn`.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                     | Descripción                                                              | Éxito |
|--------|--------------------------|--------------------------------------------------------------------------|-------|
| GET    | `/api/v1/clients`        | Lista de clientes. Con `?q=<texto>` filtra por `nombre` parcial (case-insensitive). | 200 |
| GET    | `/api/v1/clients/:id`    | Obtiene un cliente por id.                                               | 200   |
| POST   | `/api/v1/clients`        | Crea un cliente.                                                         | 201   |
| PATCH  | `/api/v1/clients/:id`    | Edita campos editables (`nombre`, `telefono`, `email`, `direccion`, `notas`). | 200 |
| DELETE | `/api/v1/clients/:id`    | Elimina un cliente (hard delete).                                        | 204   |

`DELETE` exitoso no devuelve body.

## Estructuras de datos

### Client (cliente)

| Campo      | Tipo    | Requerido | Default | Lectura | Escritura |
|------------|---------|-----------|---------|---------|-----------|
| `id`       | integer | —         | —       | sí      | no (solo lectura) |
| `nombre`   | string  | sí        | —       | sí      | sí (POST y PATCH) |
| `telefono` | string  | no        | `nil`   | sí      | sí (POST y PATCH) |
| `email`    | string  | no        | `nil`   | sí      | sí (POST y PATCH) |
| `direccion`| string  | no        | `nil`   | sí      | sí (POST y PATCH) |
| `notas`    | string  | no        | `nil`   | sí      | sí (POST y PATCH) |

Nota: `email` es opcional; si viene, debe tener formato de email válido. `telefono` es opcional y participa de la unicidad (ver invariante 3).

### Request de creación — `POST /api/v1/clients`

```json
{
  "nombre": "María López",
  "telefono": "555-1234",
  "email": "maria@example.com",
  "direccion": "Calle Falsa 123",
  "notas": "Prefiere tortas de chocolate"
}
```

Response: `201` con el `Client` creado (shape `{"data": {...Client}}`). Solo `nombre` es obligatorio; el resto puede omitirse.

### Request de edición — `PATCH /api/v1/clients/:id`

```json
{
  "telefono": "555-9999",
  "direccion": "Calle Nueva 456"
}
```

Response: `200` con el `Client` actualizado. Los campos enviados se validan igual que en la creación; los omitidos se conservan.

### Listado — `GET /api/v1/clients` (y `?q=...`)

```json
{
  "data": [
    {
      "id": 1,
      "nombre": "María López",
      "telefono": "555-1234",
      "email": "maria@example.com",
      "direccion": "Calle Falsa 123",
      "notas": "Prefiere tortas de chocolate"
    }
  ]
}
```

Con `?q=lop` se devuelven solo los clientes cuyo `nombre` contiene `lop` sin distinguir mayúsculas.

## Invariantes

1. **`nombre` es obligatorio y no vacío**. Vacío o ausente → `422 validation_failed` y no se persiste nada.
2. **`email` es opcional, pero si viene debe tener formato válido**. Formato inválido → `422 validation_failed` y no se persiste nada.
3. **Unicidad `(nombre, telefono)`**: no se permite duplicar la combinación. Duplicado → `422 cliente_duplicado` y no se persiste nada. Sin `telefono`, la unicidad no aplica.
4. **`DELETE /api/v1/clients/:id` es hard delete**: elimina el registro; `204` sin body.
5. **Filtro `q`**: `GET /api/v1/clients?q=<texto>` filtra por coincidencia **parcial** en `nombre`, **case-insensitive**. Sin `q`, lista todos.
6. `GET`, `PATCH` y `DELETE` sobre un `:id` inexistente → `404 not_found`.
7. **Frontera futura con Ventas (`cliente_con_pedidos`)**: si el cliente tiene pedidos asociados, `DELETE` → `422 cliente_con_pedidos` y el cliente queda intacto. Mientras el módulo Ventas no materialice la asociación, el guard está **dormido**: el MVP hace hard delete y no bloquea la eliminación.
8. `PATCH` valida los campos enviados con las mismas reglas que la creación; una violación → `422 validation_failed` y el cliente queda intacto.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (`contracts/agile.md`, sección Errores): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo.

Códigos de este módulo:

| Código HTTP | `code`                 | Cuándo |
|-------------|------------------------|--------|
| 422         | `validation_failed`    | `nombre` vacío/ausente; `email` con formato inválido |
| 422         | `cliente_duplicado`    | ya existe un cliente con el mismo `(nombre, telefono)` |
| 422         | `cliente_con_pedidos`  | se intenta borrar un cliente con pedidos asociados (guard futuro, hoy dormido) |
| 404         | `not_found`            | `:id` de cliente inexistente |

Los códigos `malformed_request` (400) del contrato de Backlog aplican igual aquí.

## Dependencias

- **Frontera Clientes → Ventas / Pedidos** (futura, `specs/reposteria`): Ventas asocia pedidos a un cliente. Clientes no conoce pedidos; cuando la asociación exista, el guard `cliente_con_pedidos` se activa. Hoy el hard delete es el comportamiento real.
- Este contrato **no depende** de ningún otro módulo del sistema.

## Escenarios Gherkin que ejercitan el contrato de Clientes

Spec: `specs/reposteria/clientes.feature`

- `@S-REP-20` — crear un cliente con todos sus datos → `201` con los campos devueltos.
- `@S-REP-21` — crear un cliente solo con `nombre` → `201`, sin `email` ni `telefono`.
- `@S-REP-22` — creación inválida (`nombre` vacío, `email` con formato inválido) → `422 validation_failed`, nada creado.
- `@S-REP-23` — crear un cliente con `(nombre, telefono)` ya existente → `422 cliente_duplicado`, sin duplicado.
- `@S-REP-24` — `PATCH` edita `telefono`/`direccion` y conserva el resto.
- `@S-REP-25` — `DELETE` de un cliente sin pedidos → `204` y el cliente ya no existe.
- `@S-REP-26` — `DELETE` de un cliente con pedidos asociados → `422 cliente_con_pedidos`, el cliente sigue existiendo (guard futuro, dormido).
- `@S-REP-27` — `GET /clients?q=lop` devuelve solo las coincidencias parciales de `nombre` sin distinguir mayúsculas.
- `@S-REP-28` — listar clientes y obtener uno por id → `200`, más `404 not_found` para un id inexistente.

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

---

# Contrato del módulo Productos / Recetas

Dominio: repostería. Frontera del módulo con el resto del sistema y con clientes HTTP. Gestiona productos y la receta (BOM) de insumos que consume cada unidad; el precio de venta es manual y **nunca** se deriva del costo.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Ventas / Pedidos (ver más abajo): referencia `product_id` y copia `precio_unit` como snapshot del precio al momento de vender.
- Módulo Producción (ver más abajo): lee `recipe_lines` (BOM) del producto para planificar y ejecutar el consumo de insumos.
- Módulo Reportes / Dashboard (ver más abajo): lee `costo_calculado` para calcular el margen.
- Módulo Inventario: la receta referencia un `material_id` existente; Productos **no** crea, modifica ni descuenta stock.

## Runner BDD y mutación (fijados por stack del repo)

Mismos que el módulo Inventario en este archivo: runner `cucumber-rails` y mutación `mutant` + `mutant-rspec`. Ver [Runner BDD y mutación](#runner-bdd-y-mutación-fijados-por-stack-del-repo). Los tests BDD se acotan a `features/` y se rastrean a escenarios `@S-REP-nn`.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                                        | Descripción                                                                          | Éxito |
|--------|---------------------------------------------|--------------------------------------------------------------------------------------|-------|
| POST   | `/api/v1/products`                          | Crea un producto.                                                                    | 201 |
| GET    | `/api/v1/products`                          | Lista de productos. Con `?activos=true` devuelve solo `activo = true`.               | 200 |
| GET    | `/api/v1/products/:id`                      | Obtiene un producto con `costo_calculado` y `recipe_lines`.                          | 200 |
| PATCH  | `/api/v1/products/:id`                      | Edita `nombre`, `descripcion`, `precio` y `activo`.                                  | 200 |
| POST   | `/api/v1/products/:id/recipe_lines`         | Agrega una línea de receta (`material_id`, `cantidad`).                              | 201 |
| DELETE | `/api/v1/products/:id/recipe_lines/:line_id`| Quita una línea de la receta.                                                        | 204 |

`DELETE` exitoso no devuelve body.

## Estructuras de datos

### Product (producto)

| Campo             | Tipo    | Requerido | Default   | Lectura | Escritura |
|-------------------|---------|-----------|-----------|---------|-----------|
| `id`              | integer | —         | —         | sí      | no (solo lectura) |
| `nombre`          | string  | sí        | —         | sí      | sí (POST y PATCH) |
| `descripcion`     | string  | no        | `nil`     | sí      | sí (POST y PATCH) |
| `precio`          | number  | sí        | —         | sí      | sí (POST y PATCH) |
| `activo`          | boolean | no        | `true`    | sí      | sí (POST y PATCH) |
| `costo_calculado` | number  | —         | calculado | sí      | no (solo lectura) |
| `recipe_lines`    | array   | —         | calculado | sí      | no (solo lectura; se editan vía `/recipe_lines`) |

Nota: `costo_calculado` y `recipe_lines` son derivados; no se reciben del cliente. `recipe_lines` se devuelve en `GET /api/v1/products/:id`.

### RecipeLine (línea de receta)

| Campo            | Tipo    | Requerido | Default | Lectura | Escritura |
|------------------|---------|-----------|---------|---------|-----------|
| `id`             | integer | —         | —       | sí      | no (solo lectura) |
| `material_id`    | integer | sí        | —       | sí      | sí (en `POST`) |
| `material_nombre`| string  | —         | —       | sí      | no (solo lectura, derivado del material) |
| `cantidad`       | number  | sí        | —       | sí      | sí (en `POST`) |

### Request de creación — `POST /api/v1/products`

```json
{
  "nombre": "Torta de chocolate",
  "descripcion": "Bizcochuelo con ganache",
  "precio": 120.0
}
```

Response: `201` con el `Product` creado (shape `{"data": {...Product}}`), `activo` `true` por defecto.

### Request de edición — `PATCH /api/v1/products/:id`

```json
{
  "nombre": "Torta de chocolate y dulce de leche",
  "precio": 130.0,
  "activo": false
}
```

Response: `200` con el `Product` actualizado. Mismas validaciones que la creación; los campos omitidos se conservan.

### Request de línea de receta — `POST /api/v1/products/:id/recipe_lines`

```json
{
  "material_id": 1,
  "cantidad": 2
}
```

Response: `201` con la `RecipeLine` creada (shape `{"data": {...RecipeLine}}`).

### Producto con receta y costo derivado — `GET /api/v1/products/:id`

```json
{
  "data": {
    "id": 1,
    "nombre": "Torta de chocolate",
    "descripcion": "Bizcochuelo con ganache",
    "precio": 120.0,
    "activo": true,
    "costo_calculado": 9.0,
    "recipe_lines": [
      { "id": 1, "material_id": 1, "material_nombre": "Harina", "cantidad": 2 },
      { "id": 2, "material_id": 2, "material_nombre": "Azúcar", "cantidad": 1 }
    ]
  }
}
```

Con `Harina` a `costo_unitario 3.5` y `Azúcar` a `2.0`: `costo_calculado = 3.5*2 + 2.0*1 = 9.0`.

## Invariantes

1. **`nombre` es obligatorio, no vacío y único**. Vacío/ausente → `422 validation_failed`; ya existente → `422 nombre_duplicado`. En ambos casos no se persiste nada.
2. **`precio >= 0`**. Violación → `422 validation_failed` y el producto queda intacto.
3. `activo` es booleano con default `true`; se puede desactivar por `PATCH`.
4. **`cantidad > 0`** en toda línea de receta. Violación → `422 validation_failed` y no se agrega la línea.
5. **`material_id` debe referenciar un Material existente** (frontera con Inventario); inexistente → `404 not_found` y no se agrega la línea.
6. **Un material no puede repetirse en la receta del mismo producto** → `422 material_duplicado` y la línea existente queda intacta.
7. **`costo_calculado` es derivado y no persistido**: `costo_calculado = Σ(material.costo_unitario * recipe_line.cantidad)` sobre las `recipe_lines` de la unidad. Se recalcula al consultar y refleja el estado actual de las líneas y de `material.costo_unitario`.
8. **El `precio` es de fijación manual y nunca se deriva del costo**. El margen (`precio - costo_calculado`) se calcula fuera de este módulo; Productos solo expone `costo_calculado`.
9. `DELETE /api/v1/products/:id/recipe_lines/:line_id` responde `204` sin body; producto o línea inexistente → `404 not_found`.
10. `GET /api/v1/products/:id` sobre un id inexistente → `404 not_found`.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (`contracts/agile.md`, sección Errores): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo.

Códigos de este módulo:

| Código HTTP | `code`               | Cuándo |
|-------------|----------------------|--------|
| 422         | `validation_failed`  | `nombre` vacío/ausente; `precio < 0`; `cantidad <= 0` o `material_id` ausente |
| 422         | `nombre_duplicado`   | ya existe un producto con ese `nombre` |
| 422         | `material_duplicado` | el `material_id` ya está presente en la receta del producto |
| 404         | `not_found`          | `:id` de producto inexistente; `material_id` inexistente; línea inexistente |

Los códigos `malformed_request` (400) del contrato de Backlog aplican igual aquí.

## Dependencias

- **Frontera Productos/Recetas → Inventario**: `material_id` referencia un Material existente. La receta no crea, modifica ni descuenta stock; Inventario no conoce de productos.
- **Frontera Productos/Recetas → Ventas/Pedidos** (ver contrato más abajo): Ventas referencia `product_id` y copia `precio_unit` como snapshot.
- **Frontera Productos/Recetas → Producción** (ver contrato más abajo): Producción lee el BOM y consume insumos registrando movimientos de tipo `salida` en Inventario.
- **Frontera Productos/Recetas → Reportes/Dashboard** (ver contrato más abajo): Reportes lee `costo_calculado` para el margen.

## Escenarios Gherkin que ejercitan el contrato de Productos/Recetas

Spec: `specs/reposteria/productos.feature`

- `@S-REP-30` — crear producto válido → `201`, activo, con nombre y precio.
- `@S-REP-31` — creación inválida (`nombre` vacío, `precio < 0`) → `422 validation_failed`, nada creado.
- `@S-REP-32` — crear con `nombre` ya existente → `422 nombre_duplicado`, sin duplicado.
- `@S-REP-33` — `PATCH` edita nombre/precio/activo.
- `@S-REP-34` — agregar línea de receta válida → `201`.
- `@S-REP-35` — línea con `cantidad <= 0` → `422 validation_failed`, sin líneas.
- `@S-REP-36` — línea con material inexistente → `404 not_found`, sin líneas.
- `@S-REP-37` — material repetido en la receta → `422 material_duplicado`, línea original intacta.
- `@S-REP-38` — `DELETE` de línea → `204`, sin líneas.
- `@S-REP-39` — `GET /products/:id` incluye `costo_calculado` y `recipe_lines`.
- `@S-REP-40` — listar, filtrar `?activos=true` y `404 not_found` por id inexistente.
- `@S-REP-41` — el precio **no** se deriva del costo (precio 120, costo 14).
- `@S-REP-42` — `PATCH` inválido → `422 validation_failed`, producto intacto.

---

# Contrato del módulo Ventas / Pedidos

Dominio: repostería. Frontera del módulo con el resto del sistema y con clientes HTTP. Registra pedidos con sus líneas y sigue un ciclo de vida estricto hasta la entrega.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Clientes (contrato arriba): un pedido referencia un `client_id` existente y activa el guard `cliente_con_pedidos`.
- Módulo Productos / Recetas (contrato arriba): cada línea referencia un `product_id` existente y copia `precio_unit`.
- Módulo Reportes / Dashboard (contrato más abajo): lee pedidos para ventas y dashboard.

## Runner BDD y mutación (fijados por stack del repo)

Mismos que el módulo Inventario en este archivo: runner `cucumber-rails` y mutación `mutant` + `mutant-rspec`. Ver [Runner BDD y mutación](#runner-bdd-y-mutación-fijados-por-stack-del-repo). Los tests BDD se acotan a `features/` y se rastrean a escenarios `@S-REP-nn`.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                                  | Descripción                                                                | Éxito |
|--------|---------------------------------------|----------------------------------------------------------------------------|-------|
| POST   | `/api/v1/orders`                      | Crea un pedido (`client_id`, `fecha`, `order_lines?`). Nace `pendiente`.    | 201 |
| GET    | `/api/v1/orders`                      | Lista de pedidos. Con `?estado=<estado>` filtra por estado exacto.         | 200 |
| GET    | `/api/v1/orders/:id`                  | Obtiene un pedido por id.                                                  | 200 |
| POST   | `/api/v1/orders/:id/order_lines`      | Agrega una línea y recalcula el total.                                     | 201 |
| DELETE | `/api/v1/orders/:id/order_lines/:line_id` | Quita una línea y recalcula el total.                                  | 204 |
| PATCH  | `/api/v1/orders/:id`                  | Transiciona el estado (`{estado}`).                                        | 200 |
| DELETE | `/api/v1/orders/:id`                  | Elimina un pedido pendiente.                                               | 204 |

`DELETE` exitoso no devuelve body.

## Estructuras de datos

### Order (pedido)

| Campo         | Tipo    | Requerido | Default      | Lectura | Escritura |
|---------------|---------|-----------|--------------|---------|-----------|
| `id`          | integer | —         | —            | sí      | no (solo lectura) |
| `client_id`   | integer | sí        | —            | sí      | sí (en `POST`) |
| `fecha`       | date    | sí        | —            | sí      | sí (en `POST`; ver nota) |
| `estado`      | enum    | —         | `pendiente`  | sí      | sí solo vía `PATCH` (transición estricta) |
| `total`       | number  | —         | calculado    | sí      | no (solo lectura, derivado) |
| `order_lines` | array   | no        | `[]`         | sí      | sí en `POST` (alta inicial) |

Enums:

- `estado` ∈ `{ "pendiente", "en_produccion", "entregado" }`.

Nota: `fecha` usa el vocabulario relativo de la spec (`"hoy + N"`); en el contrato HTTP es una fecha ISO-8601 válida.

### OrderLine (línea de pedido)

| Campo         | Tipo    | Requerido | Default | Lectura | Escritura |
|---------------|---------|-----------|---------|---------|-----------|
| `id`          | integer | —         | —       | sí      | no (solo lectura) |
| `product_id`  | integer | sí        | —       | sí      | sí (en el `POST` de línea) |
| `cantidad`    | integer | sí        | —       | sí      | sí |
| `precio_unit` | number  | sí        | —       | sí      | sí |

Nota: `precio_unit` se copia como snapshot del precio del producto al momento de vender.

### Request de creación — `POST /api/v1/orders`

```json
{
  "client_id": 1,
  "fecha": "2026-09-15",
  "order_lines": [
    { "product_id": 1, "cantidad": 2, "precio_unit": 10.5 },
    { "product_id": 2, "cantidad": 3, "precio_unit": 2.0 }
  ]
}
```

Response: `201` con el `Order` creado; nace en `pendiente`, con `total = 27.0`. `order_lines` es opcional: sin líneas, el pedido nace `pendiente` con `0` líneas y `total` `0`.

### Request de línea — `POST /api/v1/orders/:id/order_lines`

```json
{
  "product_id": 2,
  "cantidad": 2,
  "precio_unit": 3.0
}
```

Response: `201` con el `Order` actualizado y su `total` recalculado.

### Transición de estado — `PATCH /api/v1/orders/:id`

```json
{
  "estado": "en_produccion"
}
```

Response: `200` con el `Order` en el nuevo estado. Solo se aceptan las transiciones `pendiente → en_produccion → entregado`.

## Invariantes

1. **`total` es derivado y no persistido**: `total = Σ(order_line.cantidad * order_line.precio_unit)`; `0` si no hay líneas. Se recalcula al agregar o quitar líneas y se devuelve en la serialización.
2. **Estado inicial `pendiente`** en toda creación.
3. **`client_id` debe existir** (frontera con Clientes). Inexistente → `422 validation_failed` y no se crea el pedido.
4. **`fecha` obligatoria y parseable** como fecha válida. Ausente, con formato inválido o inexistente → `422 validation_failed` y no se crea el pedido.
5. **`cantidad` entero > 0** y **`precio_unit >= 0`**. Violación → `422 validation_failed` y no se agrega la línea.
6. **`product_id` debe existir** (frontera con Productos); inexistente → `404 not_found` y no se agrega la línea.
7. **Un producto no puede repetirse en el pedido** → `422 producto_duplicado` y no se agrega la línea.
8. **Transición estricta `pendiente → en_produccion → entregado`**, sin saltos ni retrocesos. Violación → `422 invalid_transition` y el estado persistido queda intacto.
9. **No se inicia producción de un pedido sin líneas**: `pendiente → en_produccion` con `0` líneas → `422 pedido_vacio` y el pedido sigue `pendiente`.
10. **Modificaciones solo en `pendiente`**: quitar una línea (`DELETE /:id/order_lines/:line_id`) o eliminar el pedido (`DELETE /:id`) en cualquier otro estado → `422 pedido_bloqueado`; la línea y el pedido quedan intactos.
11. `GET /api/v1/orders/:id` sobre un id inexistente → `404 not_found`.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (`contracts/agile.md`, sección Errores): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo.

Códigos de este módulo:

| Código HTTP | `code`                | Cuándo |
|-------------|-----------------------|--------|
| 422         | `validation_failed`   | `client_id` inexistente; `fecha` ausente/inválida; `cantidad <= 0`; `precio_unit < 0` |
| 422         | `producto_duplicado`  | el `product_id` ya está en el pedido |
| 422         | `pedido_bloqueado`    | quitar línea o eliminar pedido fuera de `pendiente` |
| 422         | `pedido_vacio`        | iniciar producción (`pendiente → en_produccion`) sin líneas |
| 422         | `invalid_transition`  | salto o retroceso en el ciclo de vida |
| 404         | `not_found`           | `:id` de pedido inexistente; `product_id` inexistente |

Los códigos `malformed_request` (400) del contrato de Backlog aplican igual aquí.

## Dependencias

- **Frontera Ventas → Clientes** (contrato arriba): `client_id` debe existir. Activa el guard `cliente_con_pedidos` de Clientes (ver invariante 7 de ese contrato): un cliente con pedidos no se puede borrar.
- **Frontera Ventas → Productos/Recetas** (contrato arriba): `product_id` debe existir. `precio_unit` se copia en la línea como snapshot del precio al momento de vender.
- **Frontera Ventas → Reportes/Dashboard** (contrato más abajo): Reportes lee pedidos para ventas agregadas y dashboard.

## Escenarios Gherkin que ejercitan el contrato de Ventas/Pedidos

Spec: `specs/reposteria/ventas.feature`

- `@S-REP-43` — crear pedidos con y sin líneas → `201`, `pendiente`, total derivado (`27.0` / `0`).
- `@S-REP-44` — eliminar un pedido pendiente → `204` y deja de existir.
- `@S-REP-45` — creación inválida (`client_id` inexistente, `fecha` ausente/inválida) → `422 validation_failed`, nada creado.
- `@S-REP-46` — agregar línea recalcula el total (`16.5`).
- `@S-REP-47` — línea inválida / producto inexistente / producto duplicado → `422` o `404`, pedido conserva 1 línea.
- `@S-REP-48` — quitar línea recalcula el total (`21.0`).
- `@S-REP-49` — quitar línea o eliminar pedido fuera de `pendiente` → `422 pedido_bloqueado`, intacto.
- `@S-REP-50` — transición en orden estricto `pendiente → en_produccion → entregado`.
- `@S-REP-51` — transiciones inválidas (salto/retroceso) → `422 invalid_transition`; sin líneas → `422 pedido_vacio`.
- `@S-REP-52` — listar filtrando por estado y obtener por id, más `404 not_found`.

---

# Contrato del módulo Producción

Dominio: repostería. Frontera del módulo con el resto del sistema y con clientes HTTP. Planifica, avanza, completa y da de baja órdenes de producción, consumiendo el BOM del producto contra el inventario de insumos de forma atómica.

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- Módulo Productos / Recetas (contrato arriba): lee `recipe_lines` (BOM) del product para planificar y ejecutar el consumo.
- Módulo Inventario (contrato arriba): al completar, registra movimientos de tipo `salida` que descuentan stock.
- Módulo Reportes / Dashboard (contrato más abajo): lee órdenes de producción para el resumen.

## Runner BDD y mutación (fijados por stack del repo)

Mismos que el módulo Inventario en este archivo: runner `cucumber-rails` y mutación `mutant` + `mutant-rspec`. Ver [Runner BDD y mutación](#runner-bdd-y-mutación-fijados-por-stack-del-repo). Los tests BDD se acotan a `features/` y se rastrean a escenarios `@S-REP-nn`.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                              | Descripción                                                                 | Éxito |
|--------|-----------------------------------|-----------------------------------------------------------------------------|-------|
| POST   | `/api/v1/production_orders`       | Crea una orden (`product_id`, `cantidad`, `fecha?`). Nace `planificada`.      | 201 |
| GET    | `/api/v1/production_orders`       | Lista órdenes. Con `?estado=<estado>` filtra por estado exacto.              | 200 |
| GET    | `/api/v1/production_orders/:id`   | Obtiene una orden con su consumo planificado.                               | 200 |
| PATCH  | `/api/v1/production_orders/:id`   | Transiciona el estado (`{estado}`).                                          | 200 |
| DELETE | `/api/v1/production_orders/:id`   | Elimina una orden `planificada`.                                             | 204 |

`DELETE` exitoso no devuelve body.

## Estructuras de datos

### ProductionOrder (orden de producción)

| Campo                  | Tipo    | Requerido | Default       | Lectura | Escritura |
|------------------------|---------|-----------|---------------|---------|-----------|
| `id`                   | integer | —         | —             | sí      | no (solo lectura) |
| `product_id`           | integer | sí        | —             | sí      | sí (en `POST`) |
| `producto`             | string  | —         | —             | sí      | no (solo lectura, nombre del producto) |
| `cantidad`             | integer | sí        | —             | sí      | sí (en `POST`) |
| `fecha`                | date    | no        | hoy           | sí      | sí (en `POST`) |
| `estado`               | enum    | —         | `planificada` | sí      | sí solo vía `PATCH` (transición estricta) |
| `consumo_planificado`  | array   | —         | calculado     | sí      | no (solo lectura, derivado del BOM; solo en `GET /:id`) |

Enums:

- `estado` ∈ `{ "planificada", "en_proceso", "completada" }`.

### Consumo planificado (item)

| Campo            | Tipo    | Lectura | Descripción |
|------------------|---------|---------|-------------|
| `material`       | string  | sí      | nombre del insumo del BOM |
| `cantidad_total` | number  | sí      | `recipe_line.cantidad * production_order.cantidad` |

### Request de creación — `POST /api/v1/production_orders`

```json
{
  "product_id": 1,
  "cantidad": 3,
  "fecha": "2026-09-10"
}
```

Response: `201` con la `ProductionOrder` creada; estado inicial `planificada`, `fecha` default hoy.

### Transición de estado — `PATCH /api/v1/production_orders/:id`

```json
{
  "estado": "en_proceso"
}
```

Response: `200` con la orden en el nuevo estado.

### Orden con consumo planificado — `GET /api/v1/production_orders/:id`

```json
{
  "data": {
    "id": 1,
    "product_id": 1,
    "producto": "Torta de chocolate",
    "cantidad": 3,
    "fecha": "2026-09-10",
    "estado": "planificada",
    "consumo_planificado": [
      { "material": "Harina", "cantidad_total": 1.5 },
      { "material": "Azúcar", "cantidad_total": 0.6 }
    ]
  }
}
```

Con receta `Harina 0.5`, `Azúcar 0.2` y `cantidad 3`: `1.5` y `0.6`. Es cálculo de lectura; **no** descuenta stock.

## Invariantes

1. **`cantidad` entero > 0**. Violación → `422 validation_failed` y no se crea la orden.
2. **`product_id` debe existir** (frontera con Productos). Inexistente → `422 validation_failed` y no se crea la orden.
3. **Estado inicial `planificada`**; `fecha` default hoy si no viene.
4. **Transición estricta `planificada → en_proceso → completada`**, sin saltos ni retrocesos. Violación → `422 invalid_transition` y el estado persistido queda intacto. `GET/PATCH` sobre id inexistente → `404 not_found`.
5. **Completar (`en_proceso → completada`) consume el BOM**: por cada `recipe_line` del producto se registra un `stock_movement` de tipo `salida` con `cantidad = recipe_line.cantidad * production_order.cantidad`, vía el módulo Inventario (`POST /api/v1/materials/:id/stock_movements`). El stock de cada insumo baja por la cantidad consumida.
6. **Atomicidad de completar**: si algún insumo no alcanza (la salida dejaría stock negativo) → `422 stock_insuficiente`, **sin** registrar ningún movimiento, **sin** descontar stock y **sin** cambiar el estado (la orden permanece `en_proceso`).
7. **BOM vacío**: un producto sin `recipe_lines` se completa igual (`200`, estado `completada`) sin registrar movimientos.
8. **`consumo_planificado` es derivado y de solo lectura**: `cantidad_total = recipe_line.cantidad * production_order.cantidad`; se calcula al consultar y no descuenta stock.
9. **`DELETE` solo permitido en `planificada`** → `204` sin body y la orden deja de existir. En `en_proceso` o `completada` → `422 orden_bloqueada` y la orden queda intacta. Id inexistente → `404 not_found`.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (`contracts/agile.md`, sección Errores): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo.

Códigos de este módulo:

| Código HTTP | `code`               | Cuándo |
|-------------|----------------------|--------|
| 422         | `validation_failed`  | `cantidad <= 0`; `product_id` inexistente |
| 422         | `invalid_transition` | salto o retroceso en el ciclo de vida |
| 422         | `stock_insuficiente` | completar dejaría stock negativo en algún insumo (sin efectos) |
| 422         | `orden_bloqueada`    | `DELETE` con la orden fuera de `planificada` |
| 404         | `not_found`          | `:id` de orden inexistente |

Los códigos `malformed_request` (400) del contrato de Backlog aplican igual aquí.

## Dependencias

- **Frontera Producción → Inventario** (contrato arriba): la producción escribe movimientos de tipo `salida` (con referencia a la orden) y el inventario actualiza el stock. El inventario no conoce recetas ni producción (relación unidireccional). El `422 stock_insuficiente` y la atomicidad se resuelven en conjunto con Inventario.
- **Frontera Producción → Productos/Recetas** (contrato arriba): lee `recipe_lines` (BOM) del product para planificar (`GET`) y ejecutar (`completar`) el consumo.
- **Frontera Producción → Reportes/Dashboard** (contrato más abajo): Reportes cuenta las órdenes en `en_proceso`.

## Escenarios Gherkin que ejercitan el contrato de Producción

Spec: `specs/reposteria/produccion.feature`

- `@S-REP-53` — crear orden válida → `201`, `planificada`, con producto, cantidad y fecha.
- `@S-REP-54` — creación inválida (`cantidad <= 0`, `product_id` inexistente) → `422 validation_failed`, nada creado.
- `@S-REP-55` — avanzar `planificada → en_proceso`.
- `@S-REP-56` — saltos y retrocesos → `422 invalid_transition`, estado intacto.
- `@S-REP-57` — completar consume el BOM de forma atómica y registra movimientos `salida`.
- `@S-REP-58` — completar con insumo insuficiente → `422 stock_insuficiente`, stock y estado intactos, sin movimientos.
- `@S-REP-59` — producto sin receta se completa sin movimientos.
- `@S-REP-60` — listar filtrando por estado.
- `@S-REP-61` — `GET /:id` incluye `consumo_planificado`; id inexistente → `404 not_found`.
- `@S-REP-62` — eliminar una orden `planificada` → `204` y deja de existir.
- `@S-REP-63` — eliminar orden en `en_proceso`/`completada` → `422 orden_bloqueada`, intacta.

---

# Contrato del módulo Reportes / Dashboard

Dominio: repostería. Frontera del módulo con el resto del sistema y con clientes HTTP. Agrega información de pedidos, insumos, productos/recetas y órdenes de producción. **Todos los endpoints son de solo lectura (GET): no crean ni modifican datos.**

## Módulos que usan este contrato

- Clientes HTTP del API (`/api/v1`) — frontend y consumidores externos.
- No es consumido por otros módulos; consume en modo lectura a Ventas, Inventario, Productos/Recetas y Producción.

## Runner BDD y mutación (fijados por stack del repo)

Mismos que el módulo Inventario en este archivo: runner `cucumber-rails` y mutación `mutant` + `mutant-rspec`. Ver [Runner BDD y mutación](#runner-bdd-y-mutación-fijados-por-stack-del-repo). Los tests BDD se acotan a `features/` y se rastrean a escenarios `@S-REP-nn`. La spec está marcada `@wip`: el runner la salta salvo que se incluya ese tag explícitamente.

## Endpoints de API (base `/api/v1`)

| Método | Ruta                          | Descripción                                                                 | Éxito |
|--------|-------------------------------|-----------------------------------------------------------------------------|-------|
| GET    | `/api/v1/reports/ventas`      | Ventas agregadas por día. Params opcionales `desde`, `hasta` (ISO-8601).     | 200 |
| GET    | `/api/v1/reports/stock_critico` | Insumos con `stock_actual <= stock_min` y su faltante.                     | 200 |
| GET    | `/api/v1/reports/margen`      | Margen por producto activo.                                                  | 200 |
| GET    | `/api/v1/dashboard`           | Resumen operativo del día.                                                   | 200 |

Ninguno acepta `POST`/`PATCH`/`DELETE`.

## Estructuras de datos (shapes de respuesta)

### Reporte de ventas — `GET /api/v1/reports/ventas`

```json
{
  "data": [
    { "fecha": "2026-09-08", "cantidad": 1, "total": 300 },
    { "fecha": "2026-09-09", "cantidad": 1, "total": 800 },
    { "fecha": "2026-09-10", "cantidad": 2, "total": 1500 }
  ]
}
```

| Campo      | Tipo    | Descripción |
|------------|---------|-------------|
| `fecha`    | date    | día del pedido (ISO-8601) |
| `cantidad` | integer | pedidos de ese día |
| `total`    | number  | suma de `total` de los pedidos de ese día |

### Reporte de stock crítico — `GET /api/v1/reports/stock_critico`

```json
{
  "data": [
    { "nombre": "Azúcar", "stock_actual": 1, "stock_min": 3, "faltante": 2 },
    { "nombre": "Harina", "stock_actual": 2, "stock_min": 2, "faltante": 0 }
  ]
}
```

| Campo          | Tipo   | Descripción |
|----------------|--------|-------------|
| `nombre`       | string | nombre del insumo |
| `stock_actual` | number | stock actual |
| `stock_min`    | number | stock mínimo |
| `faltante`     | number | `stock_min - stock_actual` |

### Reporte de margen — `GET /api/v1/reports/margen`

```json
{
  "data": [
    { "nombre": "Torta chica",  "precio": 100, "costo_calculado": 60, "margen": 40, "margen_pct": 40.0 },
    { "nombre": "Torta grande", "precio": 250, "costo_calculado": 0,  "margen": 250, "margen_pct": 100.0 }
  ]
}
```

| Campo            | Tipo   | Descripción |
|------------------|--------|-------------|
| `nombre`         | string | nombre del producto |
| `precio`         | number | precio de venta |
| `costo_calculado`| number | costo derivado del BOM (`0` si no tiene receta) |
| `margen`         | number | `precio - costo_calculado` |
| `margen_pct`     | number | `margen / precio * 100`, redondeado a 1 decimal |

### Dashboard — `GET /api/v1/dashboard`

```json
{
  "data": {
    "total_ventas_hoy": 1500,
    "pedidos_pendientes": 2,
    "insumos_criticos": 2,
    "producciones_en_proceso": 2
  }
}
```

| Campo                     | Tipo    | Descripción |
|---------------------------|---------|-------------|
| `total_ventas_hoy`        | number  | suma de `total` de los pedidos con fecha = hoy (sin filtro de estado) |
| `pedidos_pendientes`      | integer | pedidos en estado `pendiente` (sin filtro de fecha) |
| `insumos_criticos`        | integer | insumos con `stock_actual <= stock_min` |
| `producciones_en_proceso` | integer | órdenes de producción en estado `en_proceso` |

## Invariantes

1. **Solo lectura**: ningún endpoint de este módulo crea o modifica datos.
2. **Ventas**: rango inclusivo en ambos extremos; agrega los pedidos con fecha dentro del rango, sin filtrar por estado, ordenado por fecha ascendente. `desde` y `hasta` opcionales; sin parámetros, el default es los últimos 7 días inclusive `[hoy - 6, hoy]`.
3. **Rango de ventas inválido** (`hasta < desde`, o fecha que no parsea como ISO-8601) → `422 validation_failed`. Sin pedidos en el rango → `200` con `data: []` (no es error).
4. **Stock crítico**: incluye los insumos con `stock_actual <= stock_min` (el `<=` incluye el límite), con `faltante = stock_min - stock_actual`, ordenado por `faltante` descendente (empates por `nombre`). Sin insumos críticos → `200` con `data: []`.
5. **Margen**: solo productos activos; `margen = precio - costo_calculado` y `margen_pct = margen / precio * 100` redondeado a 1 decimal. Producto activo sin receta → `costo_calculado 0`, `margen = precio`, `margen_pct = 100.0`. Sin productos activos → `200` con `data: []`.
6. **Dashboard**: `total_ventas_hoy` suma los pedidos con fecha = hoy sin filtrar por estado; `pedidos_pendientes` cuenta los `pendiente` sin filtrar fecha; `insumos_criticos` usa `stock_actual <= stock_min`; `producciones_en_proceso` cuenta las órdenes `en_proceso`. Sin datos → todos los campos en `0` (no es error).
7. **Fronteras de lectura**: consume pedidos, insumos, productos/recetas y órdenes de producción; no escribe en esos módulos.

## Errores

Mismo shape JSON API ya definido en el contrato de Backlog (`contracts/agile.md`, sección Errores): `{"errors": [{status, code, title, detail, source}]}`. No se repite el body completo.

Códigos de este módulo:

| Código HTTP | `code`               | Cuándo |
|-------------|----------------------|--------|
| 422         | `validation_failed`  | `hasta < desde` o fecha que no parsea como ISO-8601 en `/reports/ventas` |

Los códigos `malformed_request` (400) del contrato de Backlog aplican igual aquí.

## Dependencias

- **Frontera Reportes/Dashboard → Ventas/Pedidos** (contrato arriba): lee pedidos para ventas agregadas y dashboard.
- **Frontera Reportes/Dashboard → Inventario** (contrato arriba): lee insumos para stock crítico y dashboard.
- **Frontera Reportes/Dashboard → Productos/Recetas** (contrato arriba): lee `precio` y `costo_calculado` para el margen.
- **Frontera Reportes/Dashboard → Producción** (contrato arriba): lee órdenes para el dashboard.
- Relación unidireccional: Reportes no es consumido por ningún módulo.

## Escenarios Gherkin que ejercitan el contrato de Reportes/Dashboard

Spec: `specs/reposteria/reportes.feature`

- `@S-REP-64` — ventas agrupadas por día dentro del rango, orden ascendente.
- `@S-REP-65` — default de últimos 7 días cuando no se indica rango.
- `@S-REP-66` — rango inválido (`hasta < desde`, formato no ISO) → `422 validation_failed`.
- `@S-REP-67` — sin ventas en el rango → `200` con reporte vacío.
- `@S-REP-68` — stock crítico con `faltante` y orden descendente.
- `@S-REP-69` — sin insumos críticos → `200` con reporte vacío.
- `@S-REP-70` — margen de cada producto activo (incluye sin receta → `costo 0`).
- `@S-REP-71` — sin productos activos → `200` con reporte vacío.
- `@S-REP-72` — dashboard resume el día (ventas, pendientes, críticos, en proceso).
- `@S-REP-73` — sin datos → dashboard en ceros.

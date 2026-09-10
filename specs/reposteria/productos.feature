# language: es
# Contrato de negocio del módulo Productos y recetas (BOM) del dominio repostería.
Característica: Productos y recetas (BOM)
  Como personal de la repostería
  Quiero gestionar productos y la receta de insumos que consume cada unidad
  Para conocer el costo de elaboración sin derivar de él el precio de venta

  Antecedentes:
    Dado que el API /api/v1/products está disponible

  @S-REP-30
  Escenario: Crear un producto válido
    Cuando envío una petición POST a /api/v1/products con:
      """json
      {
        "nombre": "Torta de chocolate",
        "descripcion": "Bizcochuelo con ganache",
        "precio": 120.0
      }
      """
    Entonces la respuesta es 201
    Y el producto creado tiene nombre "Torta de chocolate"
    Y el producto creado tiene precio 120.0
    Y el producto creado está activo

  @S-REP-31
  Esquema del escenario: Rechazar la creación de un producto con datos inválidos
    Cuando envío una petición POST a /api/v1/products con los campos:
      | nombre | <nombre> |
      | precio | <precio> |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y no se crea ningún producto

    Ejemplos:
      | nombre               | precio | motivo             |
      | ""                   | 120.0  | nombre obligatorio |
      | Torta de chocolate   | -1     | precio >= 0        |

  @S-REP-32
  Escenario: Rechazar la creación de un producto con nombre ya existente
    Dado que existe el producto "Torta de chocolate" con precio 120.0
    Cuando envío una petición POST a /api/v1/products con:
      """json
      {
        "nombre": "Torta de chocolate",
        "precio": 150.0
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "nombre_duplicado"
    Y no se crea un producto duplicado

  @S-REP-33
  Escenario: Editar los campos editables de un producto
    Dado que existe el producto "Torta de chocolate" con precio 120.0
    Cuando envío una petición PATCH a /api/v1/products/1 con:
      """json
      {
        "nombre": "Torta de chocolate y dulce de leche",
        "precio": 130.0,
        "activo": false
      }
      """
    Entonces la respuesta es 200
    Y el producto tiene nombre "Torta de chocolate y dulce de leche"
    Y el producto tiene precio 130.0
    Y el producto no está activo

  @S-REP-34
  Escenario: Agregar una línea de receta a un producto
    Dado que existe el insumo "Harina" con costo_unitario 3.5
    Y que existe el producto "Torta de chocolate" con precio 120.0
    Cuando envío una petición POST a /api/v1/products/1/recipe_lines con:
      """json
      {
        "material_id": 1,
        "cantidad": 2
      }
      """
    Entonces la respuesta es 201
    Y el producto "Torta de chocolate" tiene una línea de "Harina" con cantidad 2

  @S-REP-35
  Esquema del escenario: Rechazar una línea de receta con cantidad inválida
    Dado que existe el insumo "Harina" con costo_unitario 3.5
    Y que existe el producto "Torta de chocolate" con precio 120.0
    Cuando envío una petición POST a /api/v1/products/1/recipe_lines con los campos:
      | material_id | 1          |
      | cantidad    | <cantidad> |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y el producto "Torta de chocolate" no tiene líneas de receta

    Ejemplos:
      | cantidad |
      | 0        |
      | -1       |

  @S-REP-36
  Escenario: Rechazar una línea de receta con un material inexistente
    Dado que existe el producto "Torta de chocolate" con precio 120.0
    Cuando envío una petición POST a /api/v1/products/1/recipe_lines con:
      """json
      {
        "material_id": 999,
        "cantidad": 2
      }
      """
    Entonces la respuesta es 404
    Y el error tiene código "not_found"
    Y el producto "Torta de chocolate" no tiene líneas de receta

  @S-REP-37
  Escenario: Rechazar el mismo material dos veces en una receta
    Dado que existe el insumo "Harina" con costo_unitario 3.5
    Y que existe el producto "Torta de chocolate" con precio 120.0
    Y que el producto "Torta de chocolate" tiene una línea de "Harina" con cantidad 2
    Cuando envío una petición POST a /api/v1/products/1/recipe_lines con:
      """json
      {
        "material_id": 1,
        "cantidad": 1
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "material_duplicado"
    Y el producto "Torta de chocolate" tiene una línea de "Harina" con cantidad 2

  @S-REP-38
  Escenario: Quitar una línea de la receta
    Dado que existe el producto "Torta de chocolate" con precio 120.0
    Y que el producto "Torta de chocolate" tiene una línea de "Harina" con cantidad 2
    Cuando envío una petición DELETE a /api/v1/products/1/recipe_lines/1
    Entonces la respuesta es 204
    Y el producto "Torta de chocolate" no tiene líneas de receta

  @S-REP-39
  Escenario: Obtener un producto con su costo calculado y las líneas de su receta
    Dado que existe el insumo "Harina" con costo_unitario 3.5
    Y que existe el insumo "Azúcar" con costo_unitario 2.0
    Y que existe el producto "Torta de chocolate" con precio 120.0
    Y que el producto "Torta de chocolate" tiene una línea de "Harina" con cantidad 2
    Y que el producto "Torta de chocolate" tiene una línea de "Azúcar" con cantidad 1
    Cuando envío una petición GET a /api/v1/products/1
    Entonces la respuesta es 200
    Y el producto tiene precio 120.0
    Y el producto tiene costo_calculado 9.0
    Y la receta del producto incluye:
      | material | cantidad |
      | Harina   | 2        |
      | Azúcar   | 1        |

  @S-REP-40
  Escenario: Listar productos, filtrar los activos y obtener uno por id
    Dado que existen los siguientes productos:
      | nombre             | precio | activo |
      | Torta de chocolate | 120.0  | true   |
      | Budín de limón     | 80.0   | false  |
    Cuando envío una petición GET a /api/v1/products
    Entonces la respuesta es 200
    Y la respuesta devuelve 2 productos
    Cuando envío una petición GET a /api/v1/products?activos=true
    Entonces la respuesta es 200
    Y la respuesta devuelve solo los productos:
      | nombre             |
      | Torta de chocolate |
    Cuando envío una petición GET a /api/v1/products/99
    Entonces la respuesta es 404
    Y el error tiene código "not_found"

  @S-REP-41
  Escenario: El precio no se deriva del costo de la receta
    Dado que existe el insumo "Harina" con costo_unitario 3.5
    Y que existe el producto "Torta de chocolate" con precio 120.0
    Cuando envío una petición POST a /api/v1/products/1/recipe_lines con:
      """json
      {
        "material_id": 1,
        "cantidad": 4
      }
      """
    Entonces la respuesta es 201
    Y el producto tiene precio 120.0
    Y el producto tiene costo_calculado 14.0

  @S-REP-42
  Esquema del escenario: Rechazar la edición de un producto con datos inválidos
    Dado que existe el producto "Torta de chocolate" con precio 120.0
    Cuando envío una petición PATCH a /api/v1/products/1 con los campos:
      | nombre | <nombre> |
      | precio | <precio> |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y el producto "Torta de chocolate" conserva precio 120.0

    Ejemplos:
      | nombre               | precio | motivo             |
      | ""                   | 120.0  | nombre obligatorio |
      | Torta de chocolate   | -5     | precio >= 0        |

# contracts:
# - POST /api/v1/products: crear producto {nombre (obligatorio, único), descripcion (opcional),
#   precio (decimal >= 0), activo (boolean, default true)}. Éxito 201 con el Producto creado.
#   - nombre vacío/ausente o precio < 0 → 422 validation_failed, nada persistido.
#   - nombre ya existente → 422 nombre_duplicado, sin duplicado.
# - PATCH /api/v1/products/:id: edita nombre, descripcion, precio y activo. Mismas validaciones
#   que la creación. Éxito 200 con el Producto actualizado; inexistente → 404 not_found.
# - GET /api/v1/products: lista productos activos e inactivos. Con `?activos=true` filtra solo
#   activo = true. Éxito 200.
# - GET /api/v1/products/:id: devuelve el Producto, su `costo_calculado` (derivado, NO persistido)
#   y `recipe_lines`: [{ id, material_id, material_nombre, cantidad }]. Éxito 200;
#   inexistente → 404 not_found.
#   - costo_calculado = Σ(material.costo_unitario * cantidad) sobre las recipe_lines de la unidad.
# - POST /api/v1/products/:id/recipe_lines: agrega línea {material_id, cantidad}. Éxito 201.
#   - material_id debe referenciar un Material existente (frontera con Inventario);
#     inexistente → 404 not_found.
#   - cantidad <= 0 o material_id ausente → 422 validation_failed, sin persistir.
#   - material ya presente en la receta del producto → 422 material_duplicado, sin duplicar línea.
#   - producto inexistente → 404 not_found.
# - DELETE /api/v1/products/:id/recipe_lines/:line_id: quita la línea de la receta.
#   Éxito 204 sin body; producto o línea inexistente → 404 not_found.
# - precio es de fijación manual y NUNCA se deriva del costo de la receta. margen = precio -
#   costo_calculado se calcula fuera de este módulo; este módulo solo expone `costo_calculado`.
# - costo_calculado se recalcula al consultar y refleja el estado actual de las líneas y de
#   material.costo_unitario.
# - Frontera Productos/Recetas → Inventario: material_id referencia un Material existente; la
#   receta NO crea, modifica ni descuenta stock de insumos. Inventario no conoce de productos.
# - Frontera futura Productos/Recetas → Producción/Órdenes: la producción consumirá insumos
#   según la receta registrando movimientos de tipo `salida` en Inventario.
# - Frontera módulo → clientes HTTP: shape de éxito { "data": {...Producto | ...RecipeLine} } y
#   errores JSON API {"errors": [{status, code, title, detail, source}]}. Códigos del módulo:
#   validation_failed, nombre_duplicado, material_duplicado, not_found.

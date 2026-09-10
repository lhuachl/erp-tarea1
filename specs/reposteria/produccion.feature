# language: es
# Contrato de negocio del módulo Producción / órdenes de producción del dominio repostería.
#
# Vocabulario de fechas relativas (estable en el tiempo, sin fechas fijas):
#   "hoy"     = fecha actual
#   "hoy + N" = hoy más N días
#   "hoy - N" = hoy menos N días
@wip
Característica: Órdenes de producción
  Como equipo de repostería
  Quiero planificar, avanzar, completar y dar de baja órdenes de producción
  Para consumir el BOM del producto contra el inventario de insumos de forma atómica

  Antecedentes:
    Dado que el API /api/v1/production_orders está disponible
    Y que existe el producto "Torta de chocolate"

  @S-REP-53
  Escenario: Crear una orden de producción válida
    Cuando envío una petición POST a /api/v1/production_orders con:
      """json
      {
        "product_id": 1,
        "cantidad": 3,
        "fecha": "hoy"
      }
      """
    Entonces la respuesta es 201
    Y la orden creada tiene producto "Torta de chocolate"
    Y la orden creada tiene cantidad 3
    Y la orden creada tiene estado "planificada"
    Y la orden creada tiene fecha "hoy"

  @S-REP-54
  Esquema del escenario: Rechazar la creación de una orden con datos inválidos
    Cuando envío una petición POST a /api/v1/production_orders con los campos:
      | product_id | <product_id> |
      | cantidad   | <cantidad>   |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y no se crea ninguna orden

    Ejemplos:
      | product_id | cantidad | motivo               |
      | 1          | 0        | cantidad > 0         |
      | 1          | -2       | cantidad > 0         |
      | 99         | 1        | producto inexistente |

  @S-REP-55
  Escenario: Avanzar una orden de planificada a en_proceso
    Dado que existe una orden de producción del producto "Torta de chocolate" con cantidad 3 en estado "planificada"
    Cuando envío una petición PATCH a /api/v1/production_orders/1 con estado "en_proceso"
    Entonces la respuesta es 200
    Y la orden queda en estado "en_proceso"

  @S-REP-56
  Esquema del escenario: Rechazar transiciones de estado con salto o retroceso
    Dado que existe una orden de producción en estado "<estado_actual>"
    Cuando envío una petición PATCH a /api/v1/production_orders/1 con estado "<estado_solicitado>"
    Entonces la respuesta es 422
    Y el error tiene código "invalid_transition"
    Y la orden permanece en estado "<estado_actual>"

    Ejemplos:
      | estado_actual | estado_solicitado | motivo    |
      | planificada   | completada        | salto     |
      | en_proceso    | planificada       | retroceso |
      | completada    | en_proceso        | retroceso |
      | completada    | planificada       | retroceso |

  @S-REP-57
  Escenario: Completar una orden consume el BOM del producto de forma atómica
    Dado que el producto "Torta de chocolate" tiene la receta:
      | material | cantidad |
      | Harina   | 0.5      |
      | Azúcar   | 0.2      |
    Y que los insumos tienen stock:
      | material | stock_actual |
      | Harina   | 10           |
      | Azúcar   | 5            |
    Y que existe una orden de producción del producto "Torta de chocolate" con cantidad 3 en estado "en_proceso"
    Cuando envío una petición PATCH a /api/v1/production_orders/1 con estado "completada"
    Entonces la respuesta es 200
    Y la orden queda en estado "completada"
    Y los insumos quedan con stock:
      | material | stock_actual |
      | Harina   | 8.5          |
      | Azúcar   | 4.4          |
    Y se registran movimientos de stock de tipo "salida":
      | material | cantidad |
      | Harina   | 1.5      |
      | Azúcar   | 0.6      |

  @S-REP-58
  Escenario: Rechazar completar una orden si algún insumo no alcanza, sin consumir nada
    Dado que el producto "Torta de chocolate" tiene la receta:
      | material | cantidad |
      | Harina   | 0.5      |
      | Azúcar   | 0.2      |
    Y que los insumos tienen stock:
      | material | stock_actual |
      | Harina   | 10           |
      | Azúcar   | 0.4          |
    Y que existe una orden de producción del producto "Torta de chocolate" con cantidad 3 en estado "en_proceso"
    Cuando envío una petición PATCH a /api/v1/production_orders/1 con estado "completada"
    Entonces la respuesta es 422
    Y el error tiene código "stock_insuficiente"
    Y la orden permanece en estado "en_proceso"
    Y los insumos conservan su stock:
      | material | stock_actual |
      | Harina   | 10           |
      | Azúcar   | 0.4          |
    Y no se registra ningún movimiento de stock

  @S-REP-59
  Escenario: Completar un producto sin receta no consume insumos
    Dado que el producto "Brownie simple" sin receta
    Y que existe una orden de producción del producto "Brownie simple" con cantidad 2 en estado "en_proceso"
    Cuando envío una petición PATCH a /api/v1/production_orders/1 con estado "completada"
    Entonces la respuesta es 200
    Y la orden queda en estado "completada"
    Y no se registra ningún movimiento de stock

  @S-REP-60
  Escenario: Listar las órdenes filtrando por estado
    Dado que existen las siguientes órdenes de producción:
      | producto           | cantidad | estado      |
      | Torta de chocolate | 3        | planificada |
      | Brownie simple     | 2        | en_proceso  |
      | Torta de vainilla  | 1        | completada  |
    Cuando envío una petición GET a /api/v1/production_orders?estado=en_proceso
    Entonces la respuesta es 200
    Y la respuesta devuelve las órdenes:
      | producto       | cantidad | estado     |
      | Brownie simple | 2        | en_proceso |

  @S-REP-61
  Escenario: Obtener una orden incluye el consumo planificado y un id inexistente da 404
    Dado que el producto "Torta de chocolate" tiene la receta:
      | material | cantidad |
      | Harina   | 0.5      |
      | Azúcar   | 0.2      |
    Y que existe una orden de producción del producto "Torta de chocolate" con cantidad 3 en estado "planificada"
    Cuando envío una petición GET a /api/v1/production_orders/1
    Entonces la respuesta es 200
    Y la orden tiene producto "Torta de chocolate"
    Y la orden tiene cantidad 3
    Y la orden tiene estado "planificada"
    Y la respuesta incluye el consumo planificado:
      | material | cantidad_total |
      | Harina   | 1.5            |
      | Azúcar   | 0.6            |
    Cuando envío una petición GET a /api/v1/production_orders/99
    Entonces la respuesta es 404
    Y el error tiene código "not_found"

  @S-REP-62
  Escenario: Eliminar una orden planificada
    Dado que existe una orden de producción en estado "planificada"
    Cuando envío una petición DELETE a /api/v1/production_orders/1
    Entonces la respuesta es 204
    Y la orden ya no existe

  @S-REP-63
  Esquema del escenario: Rechazar eliminar una orden que no está planificada
    Dado que existe una orden de producción en estado "<estado>"
    Cuando envío una petición DELETE a /api/v1/production_orders/1
    Entonces la respuesta es 422
    Y el error tiene código "orden_bloqueada"
    Y la orden sigue existiendo

    Ejemplos:
      | estado     |
      | en_proceso |
      | completada |

# contracts:
# - POST /api/v1/production_orders: crear orden {product_id, cantidad (int > 0), fecha (default "hoy")}. El product referenciado debe existir. Éxito 201 con ProductionOrder; estado inicial "planificada". Violación (cantidad <= 0 o producto inexistente) → 422 validation_failed y no se crea nada.
# - PATCH /api/v1/production_orders/:id {estado}: ciclo de vida estricto planificada → en_proceso → completada, sin saltos ni retrocesos. Violación → 422 invalid_transition, estado persistido intacto. Inexistente → 404 not_found.
# - Completar (en_proceso → completada): consume el BOM del producto. Por cada recipe_line del producto se registra un stock_movement de tipo "salida" con cantidad = recipe_line.cantidad * production_order.cantidad, vía el módulo Inventario (POST /api/v1/materials/:id/stock_movements). El stock de cada insumo baja por la cantidad consumida.
# - Atomicidad de completar: si algún insumo no alcanza (la salida dejaría stock negativo) → 422 stock_insuficiente, SIN registrar ningún movimiento de salida, SIN descontar stock y SIN cambiar el estado (la orden permanece "en_proceso").
# - BOM vacío: un producto sin recipe_lines se completa igual (200, estado "completada") sin registrar movimientos.
# - GET /api/v1/production_orders?estado=<estado>: lista órdenes; el filtro por estado es opcional (sin filtro, todas). Éxito 200.
# - GET /api/v1/production_orders/:id: obtiene una orden. Incluye el consumo planificado derivado del BOM como [{material, cantidad_total}], con cantidad_total = recipe_line.cantidad * production_order.cantidad; es cálculo de lectura, no descuenta stock. Éxito 200; inexistente → 404 not_found.
# - DELETE /api/v1/production_orders/:id: solo permitido en estado "planificada" → 204 sin body y la orden deja de existir. En "en_proceso" o "completada" → 422 orden_bloqueada, orden intacta. Inexistente → 404 not_found.
# - Frontera Producción → Inventario: la producción escribe movimientos de tipo "salida" (con referencia a la orden) y el inventario actualiza el stock; el inventario no conoce recetas ni producción (relación unidireccional).
# - Frontera Producción → Productos/Recetas: lee recipe_lines (BOM) del product para planificar (GET) y ejecutar (completar) el consumo.
# - Frontera módulo Producción → clientes HTTP: shape { "data": { ...ProductionOrder } } para éxitos y errores JSON API estándar ({ "errors": [{status, code, title, detail, source}] }); códigos de este módulo: validation_failed, invalid_transition, stock_insuficiente, orden_bloqueada, not_found.
# - Runner BDD: cucumber-rails (features en el repo, acotadas a los tags @S-REP-nn de esta spec).

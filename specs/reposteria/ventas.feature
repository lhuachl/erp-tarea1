# language: es
# Contrato de negocio del módulo Ventas / pedidos del dominio repostería.
#
# Vocabulario de fechas relativas (estable en el tiempo, sin fechas fijas):
#   "hoy"     = fecha actual
#   "hoy + N" = hoy más N días
@wip
Característica: Gestión de ventas y pedidos
  Como personal de la repostería
  Quiero registrar pedidos con sus líneas, cobrarlos y seguir su estado
  Para saber qué producir, qué entregar y cuánto factura cada pedido

  Antecedentes:
    Dado que el API /api/v1/orders está disponible
    Y que existe el cliente "María López" con id 1
    Y que existe el producto "Torta de chocolate" con id 1
    Y que existe el producto "Cupcake" con id 2

  @S-REP-43
  Escenario: Crear pedidos con y sin líneas
    Cuando envío una petición POST a /api/v1/orders con:
      """json
      {
        "client_id": 1,
        "fecha": "hoy + 5",
        "order_lines": [
          { "product_id": 1, "cantidad": 2, "precio_unit": 10.5 },
          { "product_id": 2, "cantidad": 3, "precio_unit": 2.0 }
        ]
      }
      """
    Entonces la respuesta es 201
    Y el pedido creado está en estado "pendiente"
    Y el pedido creado tiene 2 líneas
    Y el pedido creado tiene total 27.0
    Cuando envío una petición POST a /api/v1/orders con:
      """json
      {
        "client_id": 1,
        "fecha": "hoy + 5"
      }
      """
    Entonces la respuesta es 201
    Y el pedido creado está en estado "pendiente"
    Y el pedido creado tiene 0 líneas
    Y el pedido creado tiene total 0

  @S-REP-44
  Escenario: Eliminar un pedido pendiente
    Dado que existe un pedido en estado "pendiente" sin líneas
    Cuando envío una petición DELETE a /api/v1/orders/1
    Entonces la respuesta es 204
    Y el pedido ya no existe

  @S-REP-45
  Esquema del escenario: Rechazar la creación con cliente inexistente o fecha inválida
    Cuando envío una petición POST a /api/v1/orders con:
      """json
      {
        "client_id": <client_id>,
        "fecha": "<fecha>"
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y no se crea ningún pedido

    Ejemplos:
      | client_id | fecha         | motivo            |
      | 99        | hoy + 5       | cliente inexistente |
      | 1         |               | fecha obligatoria |
      | 1         | no-es-fecha   | formato inválido  |
      | 1         | 2026-02-30    | fecha inexistente |

  @S-REP-46
  Escenario: Agregar una línea recalcula el total del pedido
    Dado que existe un pedido en estado "pendiente" con las líneas:
      | product_id | cantidad | precio_unit |
      | 1          | 1        | 10.5        |
    Cuando envío una petición POST a /api/v1/orders/1/order_lines con:
      """json
      {
        "product_id": 2,
        "cantidad": 2,
        "precio_unit": 3.0
      }
      """
    Entonces la respuesta es 201
    Y el pedido tiene 2 líneas
    Y el pedido tiene total 16.5

  @S-REP-47
  Esquema del escenario: Rechazar una línea inválida, con producto inexistente o duplicado
    Dado que existe un pedido en estado "pendiente" con las líneas:
      | product_id | cantidad | precio_unit |
      | 1          | 2        | 10.5        |
    Cuando envío una petición POST a /api/v1/orders/1/order_lines con:
      """json
      {
        "product_id": <product_id>,
        "cantidad": <cantidad>,
        "precio_unit": <precio_unit>
      }
      """
    Entonces la respuesta es <respuesta>
    Y el error tiene código "<codigo>"
    Y el pedido conserva 1 línea

    Ejemplos:
      | product_id | cantidad | precio_unit | respuesta | codigo            | motivo              |
      | 2          | 0        | 3.0         | 422       | validation_failed | cantidad > 0        |
      | 2          | -2       | 3.0         | 422       | validation_failed | cantidad > 0        |
      | 2          | 1        | -0.5        | 422       | validation_failed | precio_unit >= 0    |
      | 99         | 1        | 5.0         | 404       | not_found         | producto inexistente |
      | 1          | 1        | 10.5        | 422       | producto_duplicado | producto ya en el pedido |

  @S-REP-48
  Escenario: Quitar una línea recalcula el total del pedido
    Dado que existe un pedido en estado "pendiente" con las líneas:
      | product_id | cantidad | precio_unit |
      | 1          | 2        | 10.5        |
      | 2          | 1        | 3.0         |
    Cuando envío una petición DELETE a /api/v1/orders/1/order_lines/2
    Entonces la respuesta es 204
    Y el pedido tiene 1 línea
    Y el pedido tiene total 21.0

  @S-REP-49
  Esquema del escenario: Rechazar quitar una línea o eliminar un pedido fuera de "pendiente"
    Dado que existe un pedido en estado "<estado>" con la línea del producto 1
    Cuando envío una petición <metodo> a <ruta>
    Entonces la respuesta es 422
    Y el error tiene código "pedido_bloqueado"
    Y el pedido sigue existiendo
    Y el pedido conserva 1 línea

    Ejemplos:
      | estado        | metodo | ruta                                  |
      | en_produccion | DELETE | /api/v1/orders/1/order_lines/1        |
      | en_produccion | DELETE | /api/v1/orders/1                      |
      | entregado     | DELETE | /api/v1/orders/1                      |

  @S-REP-50
  Escenario: Transicionar un pedido en orden estricto
    Dado que existe un pedido en estado "pendiente" con la línea del producto 1
    Cuando envío una petición PATCH a /api/v1/orders/1 con estado "en_produccion"
    Entonces la respuesta es 200
    Y el pedido queda en estado "en_produccion"
    Cuando envío una petición PATCH a /api/v1/orders/1 con estado "entregado"
    Entonces la respuesta es 200
    Y el pedido queda en estado "entregado"

  @S-REP-51
  Esquema del escenario: Rechazar transiciones inválidas e iniciar producción sin líneas
    Dado que existe un pedido en estado "<estado_actual>" <condicion_lineas>
    Cuando envío una petición PATCH a /api/v1/orders/1 con estado "<estado_solicitado>"
    Entonces la respuesta es 422
    Y el error tiene código "<codigo>"
    Y el pedido permanece en estado "<estado_actual>"

    Ejemplos:
      | estado_actual | estado_solicitado | condicion_lineas             | codigo             | motivo             |
      | pendiente     | entregado         | con la línea del producto 1  | invalid_transition | salto              |
      | en_produccion | pendiente         | con la línea del producto 1  | invalid_transition | retroceso          |
      | entregado     | en_produccion     | con la línea del producto 1  | invalid_transition | retroceso          |
      | pendiente     | en_produccion     | sin líneas                   | pedido_vacio       | pedido sin líneas  |

  @S-REP-52
  Escenario: Listar pedidos filtrando por estado y obtener uno por id
    Dado que existe un pedido en estado "pendiente" con la línea del producto 1
    Y que existe un pedido en estado "entregado" con la línea del producto 1
    Cuando envío una petición GET a /api/v1/orders?estado=pendiente
    Entonces la respuesta es 200
    Y la respuesta devuelve solo los pedidos:
      | estado    | total |
      | pendiente | 10.5  |
    Cuando envío una petición GET a /api/v1/orders/1
    Entonces la respuesta es 200
    Y el pedido tiene estado "pendiente"
    Cuando envío una petición GET a /api/v1/orders/99
    Entonces la respuesta es 404
    Y el error tiene código "not_found"

# contracts:
# - POST /api/v1/orders: crea pedido {client_id, fecha, order_lines?}. Éxito 201 con Order; nace en estado "pendiente".
#   - client_id inexistente, fecha ausente/inválida → 422 validation_failed y no se crea nada.
#   - total = Σ(cantidad * precio_unit) de sus líneas (derivado; 0 si no tiene líneas); se devuelve en la serialización.
# - POST /api/v1/orders/:id/order_lines: agrega línea {product_id, cantidad, precio_unit}. Éxito 201 con el Order actualizado y su total recalculado.
#   - product_id inexistente → 404 not_found y no se agrega la línea (frontera Ventas → Productos).
#   - cantidad entero > 0; precio_unit >= 0 → violación 422 validation_failed y no se agrega la línea.
#   - el mismo product_id ya presente en el pedido → 422 producto_duplicado y no se agrega la línea.
# - DELETE /api/v1/orders/:id/order_lines/:line_id: quita una línea. Éxito 204 sin body y total recalculado.
#   - solo permitido en estado "pendiente"; en cualquier otro estado → 422 pedido_bloqueado y la línea queda intacta.
# - PATCH /api/v1/orders/:id con {estado}: transición estricta pendiente → en_produccion → entregado.
#   - salto o retroceso → 422 invalid_transition y el estado persistido queda intacto.
#   - pendiente → en_produccion con el pedido sin líneas → 422 pedido_vacio y el pedido sigue en "pendiente".
# - GET /api/v1/orders?estado=<estado>: lista pedidos; `estado` opcional filtra por estado exacto. Éxito 200.
# - GET /api/v1/orders/:id: obtiene un pedido por id. Éxito 200; inexistente → 404 not_found.
# - DELETE /api/v1/orders/:id: elimina el pedido. Éxito 204 sin body.
#   - solo permitido en estado "pendiente"; en otro estado → 422 pedido_bloqueado y el pedido queda intacto.
# - Fronteras:
#   - Ventas → Clientes: client_id debe existir; Ventas solo referencia al cliente. Activa el guard cliente_con_pedidos de Clientes (ver contracts/reposteria.md).
#   - Ventas → Productos: product_id debe existir; precio_unit se copia en la línea como snapshot del precio al momento de vender.
#   - Ventas → clientes HTTP (ver contracts/reposteria.md): shape { "data": { ...Order } } y errores JSON API estándar {"errors": [{status, code, title, detail, source}]}.
#   - Códigos de este módulo: validation_failed, producto_duplicado, pedido_bloqueado, invalid_transition, pedido_vacio, not_found.
#   - Runner BDD: cucumber-rails; mutación: mutant + mutant-rspec (fijados en contracts/reposteria.md).

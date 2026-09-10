# language: es
# Contrato de negocio del módulo Inventario / insumos del dominio repostería.
Característica: Inventario de insumos
  Como equipo de repostería
  Quiero gestionar insumos y sus movimientos de stock
  Para conocer existencias, alertar sobre stock crítico y mantener la trazabilidad

  Antecedentes:
    Dado que el API /api/v1/materials está disponible

  @S-REP-01
  Escenario: Crear un insumo válido
    Cuando envío una petición POST a /api/v1/materials con:
      """json
      {
        "nombre": "Harina",
        "unidad": "kg",
        "stock_actual": 10,
        "stock_min": 2,
        "costo_unitario": 3.5
      }
      """
    Entonces la respuesta es 201
    Y el insumo creado tiene nombre "Harina"
    Y el insumo creado tiene unidad "kg"
    Y el insumo creado tiene stock_actual 10
    Y el insumo creado tiene stock_min 2
    Y el insumo creado tiene costo_unitario 3.5

  @S-REP-02
  Esquema del escenario: Rechazar la creación de un insumo con datos inválidos
    Cuando envío una petición POST a /api/v1/materials con los campos:
      | nombre   | <nombre>   |
      | unidad   | <unidad>   |
      | stock_actual | <stock_actual> |
      | stock_min    | <stock_min>    |
      | costo_unitario | <costo_unitario> |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y no se crea ningún insumo

    Ejemplos:
      | nombre | unidad | stock_actual | stock_min | costo_unitario | motivo              |
      | ""     | kg     | 10           | 2         | 3.5            | nombre obligatorio  |
      | Harina | caja   | 10           | 2         | 3.5            | unidad inválida     |
      | Harina | kg     | -1           | 2         | 3.5            | stock_actual >= 0   |
      | Harina | kg     | 10           | -1        | 3.5            | stock_min >= 0      |
      | Harina | kg     | 10           | 2         | -0.5           | costo_unitario >= 0 |

  @S-REP-03
  Escenario: Rechazar la creación de un insumo con nombre ya existente
    Dado que existe el insumo "Harina" con unidad "kg", stock 10, stock_min 2 y costo_unitario 3.5
    Cuando envío una petición POST a /api/v1/materials con:
      """json
      {
        "nombre": "Harina",
        "unidad": "kg",
        "stock_actual": 5,
        "stock_min": 1,
        "costo_unitario": 4.0
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "nombre_duplicado"
    Y no se crea un insumo duplicado

  @S-REP-04
  Esquema del escenario: Registrar un movimiento actualiza el stock de forma atómica
    Dado que existe el insumo "Harina" con unidad "kg", stock 10, stock_min 2 y costo_unitario 3.5
    Cuando envío una petición POST a /api/v1/materials/1/stock_movements con:
      """json
      {
        "tipo": "<tipo>",
        "cantidad": <cantidad>,
        "referencia": "<referencia>"
      }
      """
    Entonces la respuesta es 201
    Y el insumo "Harina" tiene stock <stock_final>

    Ejemplos:
      | tipo    | cantidad | referencia          | stock_final |
      | entrada | 5        | compra de harina    | 15          |
      | salida  | 4        | producción de tortas | 6          |
      | ajuste  | 7        | conteo físico       | 7           |

  @S-REP-05
  Escenario: Rechazar una salida que dejaría el stock en negativo
    Dado que existe el insumo "Harina" con unidad "kg", stock 10, stock_min 2 y costo_unitario 3.5
    Cuando envío una petición POST a /api/v1/materials/1/stock_movements con:
      """json
      {
        "tipo": "salida",
        "cantidad": 12,
        "referencia": "producción de tortas"
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "stock_insuficiente"
    Y el insumo "Harina" conserva stock 10
    Y no se registra ningún movimiento

  @S-REP-06
  Esquema del escenario: Rechazar un movimiento inválido
    Dado que existe el insumo "Harina" con unidad "kg", stock 10, stock_min 2 y costo_unitario 3.5
    Cuando envío una petición POST a /api/v1/materials/1/stock_movements con los campos:
      | tipo   | <tipo>   |
      | cantidad | <cantidad> |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y el insumo "Harina" conserva stock 10
    Y no se registra ningún movimiento

    Ejemplos:
      | tipo          | cantidad | motivo         |
      | entrada       | 0        | cantidad > 0   |
      | salida        | -3       | cantidad > 0   |
      | transferencia | 5        | tipo inválido  |

  @S-REP-07
  Escenario: Listar solo los insumos con stock crítico
    Dado que existen los siguientes insumos:
      | nombre  | unidad | stock_actual | stock_min | costo_unitario |
      | Harina  | kg     | 2            | 2         | 3.5            |
      | Azúcar  | kg     | 1            | 3         | 2.0            |
      | Manteca | kg     | 8            | 2         | 5.0            |
    Cuando envío una petición GET a /api/v1/materials?solo_criticos=true
    Entonces la respuesta es 200
    Y la respuesta devuelve solo los insumos:
      | nombre |
      | Harina |
      | Azúcar |

  @S-REP-08
  Escenario: Editar los campos editables de un insumo
    Dado que existe el insumo "Harina" con unidad "kg", stock 10, stock_min 2 y costo_unitario 3.5
    Cuando envío una petición PATCH a /api/v1/materials/1 con:
      """json
      {
        "nombre": "Harina 000",
        "unidad": "g",
        "stock_min": 500,
        "costo_unitario": 4.0
      }
      """
    Entonces la respuesta es 200
    Y el insumo tiene nombre "Harina 000"
    Y el insumo tiene unidad "g"
    Y el insumo tiene stock_min 500
    Y el insumo tiene costo_unitario 4.0
    Y el insumo conserva stock 10

  @S-REP-09
  Escenario: Rechazar la edición directa del stock actual
    Dado que existe el insumo "Harina" con unidad "kg", stock 10, stock_min 2 y costo_unitario 3.5
    Cuando envío una petición PATCH a /api/v1/materials/1 con:
      """json
      {
        "stock_actual": 99
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "readonly_field"
    Y el insumo "Harina" conserva stock 10

  @S-REP-10
  Escenario: Listar los insumos y obtener uno por id
    Dado que existen los siguientes insumos:
      | nombre  | unidad | stock_actual | stock_min | costo_unitario |
      | Harina  | kg     | 10           | 2         | 3.5            |
      | Azúcar  | kg     | 5            | 1         | 2.0            |
    Cuando envío una petición GET a /api/v1/materials
    Entonces la respuesta es 200
    Y la respuesta devuelve los insumos:
      | nombre | stock_actual |
      | Harina | 10           |
      | Azúcar | 5            |
    Cuando envío una petición GET a /api/v1/materials/2
    Entonces la respuesta es 200
    Y el insumo tiene nombre "Azúcar"
    Y el insumo tiene stock_actual 5

# contracts:
# - POST /api/v1/materials: crear insumo {nombre, unidad, stock_actual, stock_min, costo_unitario}. Éxito 201.
#   Validaciones: nombre obligatorio y único; unidad ∈ {kg, g, l, ml, unidad}; stock_actual, stock_min y costo_unitario >= 0.
#   - nombre vacío / unidad inválida / valores negativos → 422 validation_failed.
#   - nombre ya existente → 422 nombre_duplicado (no se crea duplicado).
# - POST /api/v1/materials/:id/stock_movements: registrar movimiento {tipo, cantidad, referencia?}. Éxito 201.
#   - tipo ∈ {entrada, salida, ajuste}; cantidad > 0. Violación → 422 validation_failed y no se registra movimiento.
#   - entrada: stock_actual += cantidad.
#   - salida: stock_actual -= cantidad; si el resultado sería negativo → 422 stock_insuficiente, sin registrar el movimiento y stock intacto.
#   - ajuste: stock_actual = cantidad (la cantidad representa el stock nuevo).
#   - El stock del material y el movimiento se persisten de forma atómica (o ambos, o ninguno).
# - GET /api/v1/materials?solo_criticos=true: lista los insumos con stock_actual <= stock_min. Éxito 200.
# - PATCH /api/v1/materials/:id: edita nombre, unidad, stock_min y costo_unitario. Éxito 200.
#   stock_actual es de solo lectura: enviarlo → 422 readonly_field y stock intacto.
# - GET /api/v1/materials: listar insumos. Éxito 200.
# - GET /api/v1/materials/:id: obtener insumo por id. Éxito 200; id inexistente → 404 not_found.
# - Frontera módulo inventario → clientes HTTP (ver contracts/reposteria.md): shape { "data": { ...Material | ...StockMovement } } y errores JSON API estándar.
# - Frontera inventario → dominio repostería (futuro): las recetas/órdenes de producción consumirán insumos vía movimientos de tipo salida; el inventario no conoce de recetas.

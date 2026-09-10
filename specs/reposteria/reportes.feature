# language: es
# Contrato de negocio del módulo Reportes y Dashboard del dominio repostería.
#
# Vocabulario de fechas relativas (estable en el tiempo, sin fechas fijas):
#   "hoy"     = fecha actual
#   "hoy - N" = hoy menos N días
#
# Todos los endpoints de este módulo son de solo lectura (GET): no crean ni
# modifican datos. Agregan información de pedidos, insumos, productos/recetas
# y órdenes de producción.
@wip
Característica: Reportes y dashboard de la repostería
  Como dueña de la repostería
  Quiero consultar reportes agregados de ventas, stock, margen y un resumen general
  Para tomar decisiones sin alterar los datos operativos

  Antecedentes:
    Dado que el API de reportes y dashboard de repostería está disponible

  @S-REP-64
  Escenario: Agrupar las ventas por día dentro del rango solicitado
    Dado que existen los siguientes pedidos:
      | fecha   | total |
      | hoy     | 1000  |
      | hoy     | 500   |
      | hoy - 1 | 800   |
      | hoy - 2 | 300   |
    Cuando envío una petición GET a /api/v1/reports/ventas con desde "hoy - 2" y hasta "hoy"
    Entonces la respuesta es 200
    Y el reporte de ventas devuelve:
      | fecha   | cantidad | total |
      | hoy - 2 | 1        | 300   |
      | hoy - 1 | 1        | 800   |
      | hoy     | 2        | 1500  |

  @S-REP-65
  Escenario: Usar los últimos 7 días cuando no se indica rango
    Dado que existen los siguientes pedidos:
      | fecha   | total |
      | hoy     | 1000  |
      | hoy - 6 | 200   |
      | hoy - 7 | 999   |
    Cuando envío una petición GET a /api/v1/reports/ventas
    Entonces la respuesta es 200
    Y el reporte de ventas devuelve:
      | fecha   | cantidad | total |
      | hoy - 6 | 1        | 200   |
      | hoy     | 1        | 1000  |

  @S-REP-66
  Esquema del escenario: Rechazar un rango de fechas inválido
    Cuando envío una petición GET a /api/v1/reports/ventas con los parámetros:
      | desde | <desde> |
      | hasta | <hasta> |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"

    Ejemplos:
      | desde      | hasta   | motivo                  |
      | hoy        | hoy - 1 | hasta anterior a desde  |
      | 01-09-2026 | hoy     | formato de fecha no ISO |
      | hoy - 5    | nope    | formato de fecha no ISO |

  @S-REP-67
  Escenario: Devolver una lista vacía cuando no hay ventas en el rango
    Cuando envío una petición GET a /api/v1/reports/ventas con desde "hoy - 2" y hasta "hoy"
    Entonces la respuesta es 200
    Y el reporte de ventas está vacío

  @S-REP-68
  Escenario: Listar los insumos con stock crítico y su faltante
    Dado que existen los siguientes insumos:
      | nombre  | stock_actual | stock_min |
      | Harina  | 2            | 2         |
      | Azúcar  | 1            | 3         |
      | Manteca | 8            | 2         |
    Cuando envío una petición GET a /api/v1/reports/stock_critico
    Entonces la respuesta es 200
    Y el reporte de stock crítico devuelve:
      | nombre | stock_actual | stock_min | faltante |
      | Azúcar | 1            | 3         | 2        |
      | Harina | 2            | 2         | 0        |

  @S-REP-69
  Escenario: Devolver una lista vacía cuando no hay insumos críticos
    Dado que existen los siguientes insumos:
      | nombre  | stock_actual | stock_min |
      | Harina  | 10           | 2         |
      | Manteca | 8            | 2         |
    Cuando envío una petición GET a /api/v1/reports/stock_critico
    Entonces la respuesta es 200
    Y el reporte de stock crítico está vacío

  @S-REP-70
  Escenario: Calcular el margen de cada producto activo
    Dado que existen los siguientes productos:
      | nombre       | precio | activo | costo_receta |
      | Torta chica  | 100    | true   | 60           |
      | Torta grande | 250    | true   |              |
      | Budín        | 80     | false  | 30           |
    Cuando envío una petición GET a /api/v1/reports/margen
    Entonces la respuesta es 200
    Y el reporte de margen devuelve:
      | nombre       | precio | costo_calculado | margen | margen_pct |
      | Torta chica  | 100    | 60              | 40     | 40.0       |
      | Torta grande | 250    | 0               | 250    | 100.0      |

  @S-REP-71
  Escenario: Devolver una lista vacía cuando no hay productos activos
    Dado que existen los siguientes productos:
      | nombre | precio | activo | costo_receta |
      | Budín  | 80     | false  | 30           |
    Cuando envío una petición GET a /api/v1/reports/margen
    Entonces la respuesta es 200
    Y el reporte de margen está vacío

  @S-REP-72
  Escenario: Resumir la operación del día en el dashboard
    Dado que existen los siguientes pedidos:
      | fecha   | estado    | total |
      | hoy     | pendiente | 1000  |
      | hoy     | entregado | 500   |
      | hoy - 1 | pendiente | 300   |
    Y que existen los siguientes insumos:
      | nombre  | stock_actual | stock_min |
      | Harina  | 1            | 2         |
      | Azúcar  | 5            | 5         |
      | Manteca | 8            | 2         |
    Y que existen las siguientes órdenes de producción:
      | estado     |
      | en_proceso |
      | en_proceso |
      | terminada  |
    Cuando envío una petición GET a /api/v1/dashboard
    Entonces la respuesta es 200
    Y el dashboard tiene total_ventas_hoy 1500
    Y el dashboard tiene pedidos_pendientes 2
    Y el dashboard tiene insumos_criticos 2
    Y el dashboard tiene producciones_en_proceso 2

  @S-REP-73
  Escenario: Devolver el dashboard en ceros cuando no hay datos
    Cuando envío una petición GET a /api/v1/dashboard
    Entonces la respuesta es 200
    Y el dashboard tiene total_ventas_hoy 0
    Y el dashboard tiene pedidos_pendientes 0
    Y el dashboard tiene insumos_criticos 0
    Y el dashboard tiene producciones_en_proceso 0

# contracts:
# - Todos los endpoints son de solo lectura (GET): no crean ni modifican datos.
# - GET /api/v1/reports/ventas?desde=YYYY-MM-DD&hasta=YYYY-MM-DD: ventas agregadas por día.
#   Response 200 `{ "data": [ { "fecha": "YYYY-MM-DD", "cantidad": N, "total": number }, ... ] }`, ordenado por fecha ascendente.
#   - `desde` y `hasta` opcionales; sin parámetros el default es últimos 7 días inclusive: [hoy - 6, hoy].
#   - Rango inclusivo en ambos extremos; agrega los pedidos con fecha dentro del rango (sin filtro de estado).
#   - Rango inválido (`hasta` < `desde`, o fecha que no parsea como ISO-8601) → 422 validation_failed.
#   - Sin pedidos en el rango → 200 con `data: []` (no es error).
# - GET /api/v1/reports/stock_critico: insumos con stock_actual <= stock_min (incluye el límite).
#   Response 200 `{ "data": [ { "nombre", "stock_actual", "stock_min", "faltante" }, ... ] }`,
#   con faltante = stock_min - stock_actual, ordenado por faltante descendente (empates por nombre).
#   - Sin insumos críticos → 200 con `data: []`.
# - GET /api/v1/reports/margen: margen por producto activo.
#   Response 200 `{ "data": [ { "nombre", "precio", "costo_calculado", "margen", "margen_pct" }, ... ] }`.
#   - margen = precio - costo_calculado; margen_pct = margen / precio * 100 (redondeado a 1 decimal).
#   - Producto activo sin receta → costo_calculado 0 (margen = precio, margen_pct = 100.0).
#   - Solo productos activos; sin productos activos → 200 con `data: []`.
# - GET /api/v1/dashboard: resumen agregado.
#   Response 200 `{ "data": { "total_ventas_hoy": number, "pedidos_pendientes": N,
#                             "insumos_criticos": N, "producciones_en_proceso": N } }`.
#   - total_ventas_hoy = suma de `total` de los pedidos con fecha = hoy (sin filtro de estado).
#   - pedidos_pendientes = cantidad de pedidos en estado "pendiente" (sin filtro de fecha).
#   - insumos_criticos = cantidad de insumos con stock_actual <= stock_min.
#   - producciones_en_proceso = cantidad de órdenes de producción en estado "en_proceso".
#   - Sin datos → todos los campos en 0 (no error).
# - Fronteras de lectura: consume pedidos (ventas), insumos (inventario), productos/recetas y órdenes de producción.
#   No escribe en esos módulos.
# - Cliente HTTP: shape `{ "data": ... }` para éxitos y errores JSON API estándar
#   (ver contracts/reposteria.md); único código propio de este módulo: validation_failed.

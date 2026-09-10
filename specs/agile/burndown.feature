# language: es
# Contrato de negocio del módulo Burndown + Velocity del dominio agile.
#
# Vocabulario de fechas relativas (estable en el tiempo, sin fechas fijas):
#   "hoy"     = fecha actual
#   "hoy + N" = hoy más N días
#   "hoy - N" = hoy menos N días
Característica: Burndown chart y velocity del dominio ágil
  Como equipo de repostería en el workspace único (clave "REP")
  Quiero consultar el burndown de un sprint y la velocity histórica
  Para visualizar el avance ideal contra el real y ajustar la planificación

  Antecedentes:
    Dado que existe un workspace único de repostería con clave "REP"
    Y que los endpoints /api/v1/sprints/:id/burndown y /api/v1/velocity están disponibles

  @S-AGL-30
  Escenario: Construir el burndown de un sprint activo con ideal, real y huecos
    Dado que existe un sprint en estado "activo" del "hoy - 6" al "hoy"
    Y que ese sprint tiene las historias:
      | titulo                    | story_points | estado    |
      | Cobrar pedidos pendientes | 4            | done      |
      | Reparto del turno tarde   | 2            | en_sprint |
    Y que ese sprint tiene los snapshots:
      | fecha   | puntos_restantes |
      | hoy - 6 | 6                |
      | hoy - 3 | 4                |
      | hoy     | 2                |
    Cuando envío una petición GET a /api/v1/sprints/1/burndown
    Entonces la respuesta es 200
    Y el burndown tiene total_puntos 6
    Y el burndown tiene fecha_inicio "hoy - 6"
    Y el burndown tiene fecha_fin "hoy"
    Y el burndown devuelve el ideal:
      | fecha   | restante |
      | hoy - 6 | 6        |
      | hoy - 5 | 5        |
      | hoy - 4 | 4        |
      | hoy - 3 | 3        |
      | hoy - 2 | 2        |
      | hoy - 1 | 1        |
      | hoy     | 0        |
    Y el burndown devuelve el real:
      | fecha   | puntos_restantes |
      | hoy - 6 | 6                |
      | hoy - 3 | 4                |
      | hoy     | 2                |
    Y el burndown devuelve los huecos:
      | fecha   |
      | hoy - 5 |
      | hoy - 4 |
      | hoy - 2 |
      | hoy - 1 |

  @S-AGL-31
  Escenario: El burndown también está disponible para un sprint cerrado
    Dado que existe un sprint en estado "cerrado" del "hoy - 14" al "hoy - 8"
    Y que ese sprint tiene una historia asignada con 5 puntos
    Cuando envío una petición GET a /api/v1/sprints/1/burndown
    Entonces la respuesta es 200
    Y el burndown tiene total_puntos 5
    Y el burndown tiene fecha_inicio "hoy - 14"
    Y el burndown tiene fecha_fin "hoy - 8"

  @S-AGL-32
  Esquema del escenario: Rechazar el burndown de un sprint no iniciado o inexistente
    Dado que <situacion>
    Cuando envío una petición GET a /api/v1/sprints/<sprint_id>/burndown
    Entonces la respuesta es <http>
    Y el error tiene código "<codigo>"

    Ejemplos:
      | situacion                             | sprint_id | http | codigo             |
      | existe un sprint en estado "planning" | 1         | 422  | sprint_no_iniciado |
      | no existe ningún sprint con id 999    | 999       | 404  | not_found          |

  @S-AGL-33
  Escenario: Recalcular el ideal cuando se agrega una historia después de iniciar el sprint
    Dado que existe un sprint en estado "activo" del "hoy - 4" al "hoy + 4"
    Y que ese sprint tiene historias asignadas por 8 puntos en total
    Y que en "hoy - 2" se agregó al sprint una historia de 4 puntos
    Cuando envío una petición GET a /api/v1/sprints/1/burndown
    Entonces la respuesta es 200
    Y el burndown tiene total_puntos 12
    Y el burndown devuelve el ideal:
      | fecha   | restante |
      | hoy - 4 | 8        |
      | hoy - 3 | 7        |
      | hoy - 2 | 12       |
      | hoy - 1 | 10       |
      | hoy     | 8        |
      | hoy + 1 | 6        |
      | hoy + 2 | 4        |
      | hoy + 3 | 2        |
      | hoy + 4 | 0        |

  @S-AGL-34
  Escenario: Un sprint con 0 puntos no rompe el burndown
    Dado que existe un sprint en estado "activo" del "hoy - 3" al "hoy + 3"
    Y que ese sprint tiene una historia asignada con 0 puntos
    Cuando envío una petición GET a /api/v1/sprints/1/burndown
    Entonces la respuesta es 200
    Y el burndown tiene total_puntos 0
    Y el burndown devuelve el ideal:
      | fecha   | restante |
      | hoy - 3 | 0        |
      | hoy - 2 | 0        |
      | hoy - 1 | 0        |
      | hoy     | 0        |
      | hoy + 1 | 0        |
      | hoy + 2 | 0        |
      | hoy + 3 | 0        |

  @S-AGL-35
  Escenario: Calcular la velocity de los sprints cerrados
    Dado que existen los siguientes sprints:
      | nombre   | fecha_inicio | fecha_fin | estado  |
      | Sprint 1 | hoy - 28     | hoy - 21  | cerrado |
      | Sprint 2 | hoy - 14     | hoy - 7   | cerrado |
      | Sprint 3 | hoy - 6      | hoy - 1   | cerrado |
    Y que el "Sprint 1" tiene las historias:
      | titulo           | story_points | estado |
      | Cobrar pedidos   | 3            | done   |
      | Reparto tarde    | 3            | done   |
    Y que el "Sprint 2" tiene las historias:
      | titulo           | story_points | estado    |
      | Torta cumpleaños | 4            | done      |
      | Sellar caja      | 2            | done      |
      | Ajustar receta   | 3            | en_sprint |
    Y que el "Sprint 3" tiene las historias:
      | titulo            | story_points | estado    |
      | Inventario harina | 6            | done      |
      | Comprar moldes    | 3            | done      |
      | Ordenar vitrina   | 2            | en_sprint |
    Cuando envío una petición GET a /api/v1/velocity
    Entonces la respuesta es 200
    Y la velocity devuelve:
      | nombre   | puntos_comprometidos | puntos_completados |
      | Sprint 1 | 6                    | 6                  |
      | Sprint 2 | 9                    | 6                  |
      | Sprint 3 | 11                   | 9                  |
    Y el promedio de puntos completados es 7.0
    Y la tendencia es "sube"

  @S-AGL-36
  Esquema del escenario: La tendencia compara el último sprint cerrado contra el promedio
    Dado que existen los siguientes sprints cerrados:
      | nombre   | fecha_inicio | fecha_fin | puntos_completados |
      | Sprint 1 | hoy - 28     | hoy - 21  | <c1>               |
      | Sprint 2 | hoy - 14     | hoy - 7   | <c2>               |
      | Sprint 3 | hoy - 6      | hoy - 1   | <c3>               |
    Cuando envío una petición GET a /api/v1/velocity
    Entonces la respuesta es 200
    Y el promedio de puntos completados es <promedio>
    Y la tendencia es "<tendencia>"

    Ejemplos:
      | c1 | c2 | c3 | promedio | tendencia |
      | 4  | 4  | 7  | 5.0      | sube      |
      | 7  | 7  | 4  | 6.0      | baja      |
      | 6  | 6  | 6  | 6.0      | estable   |

  @S-AGL-37
  Escenario: Sin sprints cerrados la velocity es vacía y el promedio es cero
    Dado que solo existe un sprint en estado "activo"
    Cuando envío una petición GET a /api/v1/velocity
    Entonces la respuesta es 200
    Y la velocity no devuelve ningún sprint
    Y el promedio de puntos completados es 0
    Y la tendencia es "estable"

# contracts:
# - GET /api/v1/sprints/:id/burndown
#   - Acceso: solo sprint "activo" o "cerrado". Si no existe → 404 not_found; si "planning" → 422 sprint_no_iniciado.
#   - Respuesta 200 { "data": Burndown }.
#   - Burndown = {
#       total_puntos: integer,
#       fecha_inicio: date "hoy - N",
#       fecha_fin:    date "hoy + N",
#       ideal: [ { fecha, restante } ],
#       real:  [ { fecha, puntos_restantes } ],
#       huecos:[ { fecha } ]
#     }  (ideal/real/huecos ordenados por fecha asc)
#   - total_puntos = Σ story_points de las historias con sprint_id = :id, en cualquier estado (done incluido).
#   - ideal: una entrada por cada fecha del rango [fecha_inicio, fecha_fin]. Descenso lineal desde
#       total_puntos en fecha_inicio hasta 0 en fecha_fin:
#       restante(i) = total_puntos * (N - i) / N, con N = (fecha_fin - fecha_inicio) días e i = 0..N.
#       Si total_puntos = 0 (historia con 0 puntos) o N = 0, restante = 0 en todas las fechas (sin división por cero).
#   - Scope change: si una historia se asigna al sprint en una fecha > fecha_inicio, la línea ideal se
#       recalcula desde esa fecha (fecha de asignación `agregado_en` del BacklogItem) con el nuevo total;
#       el tramo anterior conserva la línea del total previo y se admite el salto vertical en el corte.
#   - real: snapshots del sprint (DailySnapshot.puntos_restantes) ordenados por fecha asc.
#   - huecos: fechas del rango sin snapshot (días sin daily), orden asc; incluye días futuros aún sin snapshot.
#   - Fronteras (solo lectura): Sprint (fechas, estado) y DailySnapshot (fecha, puntos_restantes);
#       BacklogItem (story_points, sprint_id, estado, agregado_en).
#
# - GET /api/v1/velocity
#   - Respuesta 200 { "data": { sprints: [VelocitySprint], promedio: number, tendencia: "sube"|"baja"|"estable" } }.
#   - VelocitySprint = { nombre, puntos_comprometidos, puntos_completados }, uno por sprint "cerrado",
#       ordenados por fecha_fin asc (el último es el de mayor fecha_fin).
#   - puntos_comprometidos = Σ story_points de las historias del sprint, en cualquier estado.
#   - puntos_completados   = Σ story_points de las historias del sprint en estado "done".
#   - promedio = media aritmética de puntos_completados de los sprints cerrados.
#   - tendencia = último sprint cerrado vs promedio: último > promedio → "sube"; último < promedio → "baja";
#       último = promedio → "estable".
#   - Sin sprints cerrados: sprints = [], promedio = 0, tendencia = "estable".
#   - Fronteras (solo lectura): Sprint (nombre, fechas, estado) y BacklogItem (story_points, estado, sprint_id).
#
# - Frontera HTTP común: shape { "data": ... } y errores JSON API estándar {"errors": [{status, code, ...}]}.
#   El escenario @S-AGL-32 documenta 404 not_found y 422 sprint_no_iniciado como fronteras del burndown.

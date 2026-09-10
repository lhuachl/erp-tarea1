# language: es
# Contrato de negocio del módulo Sprints y daily snapshots (burndown) del dominio agile.
Característica: Sprints y daily snapshots del dominio ágil
  Como equipo de repostería en el workspace único (clave "REP")
  Quiero gestionar sprints con un ciclo de vida estricto y registrar un snapshot diario de puntos y horas restantes
  Para sostener el burndown chart y garantizar que solo haya una ceremonia activa a la vez

  Antecedentes:
    Dado que existe un workspace único de repostería con clave "REP"
    Y que el API /api/v1/sprints está disponible

  @S-AGL-10
  Escenario: Crear un sprint válido
    Cuando envío una petición POST a /api/v1/sprints con:
      """json
      {
        "nombre": "Sprint 1",
        "objetivo": "Ordenar el flujo de cobro",
        "fecha_inicio": "2026-09-07",
        "fecha_fin": "2026-09-18"
      }
      """
    Entonces la respuesta es 201
    Y el sprint creado tiene nombre "Sprint 1"
    Y el sprint creado tiene estado "planning"

  @S-AGL-11
  Esquema del escenario: Rechazar la creación de un sprint con datos inválidos
    Cuando envío una petición POST a /api/v1/sprints con los campos:
      | nombre       | fecha_inicio | fecha_fin  |
      | <nombre>     | <fecha_inicio> | <fecha_fin> |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"
    Y no se crea ningún sprint

    Ejemplos:
      | nombre   | fecha_inicio | fecha_fin  | motivo                       |
      | ""       | 2026-09-07   | 2026-09-18 | nombre obligatorio           |
      | Sprint 1 | 2026-09-18   | 2026-09-07 | fecha_fin >= fecha_inicio    |
      | Sprint 1 | 2026-08-01   | 2026-08-14 | fechas de hoy en adelante    |

  @S-AGL-12
  Escenario: Activar y cerrar un sprint siguiendo el ciclo de vida en orden estricto
    Dado que existe un sprint en estado "planning" del 2026-09-07 al 2026-09-18
    Y que ese sprint tiene una historia de usuario en estado "en_sprint" (sin historias "done")
    Cuando envío una petición PATCH a /api/v1/sprints/1 con estado "activo"
    Entonces la respuesta es 200
    Y el sprint queda en estado "activo"
    Cuando envío una petición PATCH a /api/v1/sprints/1 con estado "cerrado"
    Entonces la respuesta es 200
    Y el sprint queda en estado "cerrado"

  @S-AGL-13
  Esquema del escenario: Rechazar transiciones de sprint con salto o retroceso
    Dado que existe un sprint en estado "<estado_actual>"
    Cuando envío una petición PATCH a /api/v1/sprints/1 con estado "<estado_solicitado>"
    Entonces la respuesta es 422
    Y el error tiene código "invalid_transition"
    Y el sprint permanece en estado "<estado_actual>"

    Ejemplos:
      | estado_actual | estado_solicitado | motivo    |
      | planning      | cerrado           | salto     |
      | activo        | planning          | retroceso |
      | cerrado       | activo            | retroceso |

  @S-AGL-14
  Escenario: Rechazar activar un segundo sprint cuando ya existe uno activo
    Dado que existe un sprint en estado "activo"
    Y que existe otro sprint en estado "planning" con una historia asignada
    Cuando envío una petición PATCH a /api/v1/sprints/2 con estado "activo"
    Entonces la respuesta es 422
    Y el error tiene código "sprint_activo_duplicado"
    Y el sprint 2 permanece en estado "planning"

  @S-AGL-15
  Escenario: Rechazar activar un sprint sin historias asignadas
    Dado que existe un sprint en estado "planning" sin historias de usuario asignadas
    Cuando envío una petición PATCH a /api/v1/sprints/1 con estado "activo"
    Entonces la respuesta es 422
    Y el error tiene código "sprint_vacio"
    Y el sprint permanece en estado "planning"

  @S-AGL-16
  Escenario: Registrar el daily snapshot de un sprint activo
    Dado que existe un sprint en estado "activo" del 2026-09-07 al 2026-09-18
    Y que hoy es el 2026-09-09
    Cuando envío una petición POST a /api/v1/sprints/1/daily_snapshots con:
      """json
      {
        "fecha": "2026-09-09",
        "puntos_restantes": 21,
        "horas_restantes": 40
      }
      """
    Entonces la respuesta es 201
    Y el snapshot creado tiene fecha "2026-09-09"
    Y el snapshot creado tiene puntos_restantes 21
    Y el snapshot creado tiene horas_restantes 40

  @S-AGL-17
  Esquema del escenario: Rechazar un daily snapshot inválido
    Dado que hoy es el 2026-09-09
    Y que existe un sprint en estado "<estado_sprint>" del 2026-09-07 al 2026-09-18
    Cuando envío una petición POST a /api/v1/sprints/1/daily_snapshots con los campos:
      | fecha            | puntos_restantes | horas_restantes |
      | <fecha>          | <puntos_restantes> | <horas_restantes> |
    Entonces la respuesta es 422
    Y el error tiene código "<codigo_error>"
    Y no se crea ningún snapshot

    Ejemplos:
      | estado_sprint | fecha      | puntos_restantes | horas_restantes | codigo_error      |
      | planning      | 2026-09-09 | 21               | 40              | sprint_no_activo  |
      | activo        | 2026-09-01 | 21               | 40              | validation_failed |
      | activo        | 2026-10-01 | 21               | 40              | validation_failed |
      | activo        | 2026-09-09 | -1               | 40              | validation_failed |
      | activo        | 2026-09-09 | 21               | -5              | validation_failed |

  @S-AGL-18
  Escenario: Rechazar un segundo snapshot para el mismo día del mismo sprint
    Dado que existe un sprint en estado "activo" del 2026-09-07 al 2026-09-18
    Y que hoy es el 2026-09-09
    Y que ese sprint ya tiene un snapshot con fecha "2026-09-09"
    Cuando envío una petición POST a /api/v1/sprints/1/daily_snapshots con:
      """json
      {
        "fecha": "2026-09-09",
        "puntos_restantes": 18,
        "horas_restantes": 32
      }
      """
    Entonces la respuesta es 422
    Y el error tiene código "snapshot_duplicado"
    Y el snapshot existente mantiene puntos_restantes 21

  @S-AGL-19
  Escenario: Listar los sprints con su estado y obtener uno por id
    Dado que existen los siguientes sprints:
      | nombre   | fecha_inicio | fecha_fin  | estado  |
      | Sprint 1 | 2026-08-24   | 2026-09-04 | cerrado |
      | Sprint 2 | 2026-09-07   | 2026-09-18 | activo  |
    Cuando envío una petición GET a /api/v1/sprints
    Entonces la respuesta es 200
    Y la respuesta devuelve los sprints:
      | nombre   | estado  |
      | Sprint 1 | cerrado |
      | Sprint 2 | activo  |
    Cuando envío una petición GET a /api/v1/sprints/2
    Entonces la respuesta es 200
    Y el sprint tiene nombre "Sprint 2"
    Y el sprint tiene estado "activo"

# contracts:
# - POST /api/v1/sprints: crear sprint (nombre obligatorio, objetivo, fecha_inicio, fecha_fin). Éxito 201 con Sprint; estado inicial "planning". fecha_fin >= fecha_inicio y ambas de hoy en adelante; violación → 422 validation_failed.
# - PATCH /api/v1/sprints/:id (estado): ciclo de vida estricto planning → activo → cerrado, sin saltos ni retrocesos. Violación → 422 invalid_transition, estado persistido intacto.
# - Regla de unicidad: solo un sprint "activo" a la vez en el workspace "REP". Activar un segundo → 422 sprint_activo_duplicado.
# - Regla de sprint no vacío: activar exige al menos una backlog_item en estado "en_sprint" con sprint_id referenciando al sprint. Si no → 422 sprint_vacio.
# - POST /api/v1/sprints/:id/daily_snapshots: crear snapshot {fecha, puntos_restantes, horas_restantes}. Requiere sprint "activo" (si no → 422 sprint_no_activo); fecha = hoy (o dentro del rango del sprint) (si no → 422 validation_failed); enteros >= 0 (si no → 422 validation_failed); un snapshot por (sprint, fecha) (duplicado → 422 snapshot_duplicado).
# - GET /api/v1/sprints: listar sprints con su estado. Éxito 200.
# - GET /api/v1/sprints/:id: obtener sprint por id. Éxito 200.
# - Frontera módulo agile → clientes HTTP (ver contracts/agile.md): shape { "data": { ...Sprint | ...DailySnapshot } } y errores JSON API estándar.
# - Frontera con módulo backlog: la asignación de historias ocurre al transicionar backlog_item a "en_sprint"; el item guarda sprint_id (cubierto en backlog.feature @S-AGL-03/04).
# - Frontera con módulo Kanban (futuro): el cierre del sprint aún no exige tareas sin done; se limitará cuando llegue ese módulo.

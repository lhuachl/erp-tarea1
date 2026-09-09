# language: es
# Contrato de negocio del módulo Backlog (historias de usuario) del dominio agile.
Característica: Backlog de historias de usuario
  Como equipo de repostería en el workspace único (clave "REP")
  Quiero crear, editar y priorizar historias de usuario y moverlas por el flujo de trabajo
  Para mantener un backlog ordenado y priorizado por WSJF sin saltos de estado

  Antecedentes:
    Dado que existe un workspace único de repostería con clave "REP"
    Y que el API /api/v1/backlog_items está disponible

  @S-AGL-01
  Escenario: Crear una historia de usuario válida en el backlog
    Cuando envío una petición POST a /api/v1/backlog_items con:
      """json
      {
        "titulo": "Cobrar pedidos pendientes",
        "descripcion": "Cobrar los pedidos del día antes del cierre",
        "prioridad": "alta",
        "story_points": 3,
        "cod_value": 8,
        "cod_time_criticality": 5,
        "cod_risk_reduction": 3,
        "cod_duration": 2
      }
      """
    Entonces la respuesta es 201
    Y la historia creada tiene estado "backlog"
    Y la respuesta incluye wsjf igual a 8.0

  @S-AGL-02
  Esquema del escenario: Rechazar la creación de una historia con datos inválidos
    Cuando envío una petición POST a /api/v1/backlog_items con los campos:
      | titulo       | <titulo>       |
      | story_points | <story_points> |
      | prioridad    | <prioridad>    |
    Entonces la respuesta es 422
    Y el error tiene código "validation_failed"

    Ejemplos:
      | titulo            | story_points | prioridad | motivo             |
      | ""                | 3            | media     | título obligatorio |
      | "Cobrar pedidos"  | 0            | media     | story_points > 0   |
      | "Cobrar pedidos"  | -2           | media     | story_points > 0   |
      | "Cobrar pedidos"  | 3            | urgente   | prioridad inválida |

  @S-AGL-03
  Escenario: Transicionar una historia a lo largo del flujo en orden estricto
    Dado que existe una historia de usuario en estado "backlog"
    Cuando envío una petición PATCH a /api/v1/backlog_items/1 con estado "listo"
    Entonces la respuesta es 200
    Y la historia queda en estado "listo"
    Cuando envío una petición PATCH a /api/v1/backlog_items/1 con estado "en_sprint"
    Entonces la respuesta es 200
    Y la historia queda en estado "en_sprint"
    Cuando envío una petición PATCH a /api/v1/backlog_items/1 con estado "done"
    Entonces la respuesta es 200
    Y la historia queda en estado "done"

  @S-AGL-04
  Esquema del escenario: Rechazar transiciones de estado con salto o retroceso
    Dado que existe una historia de usuario en estado "<estado_actual>"
    Cuando envío una petición PATCH a /api/v1/backlog_items/1 con estado "<estado_solicitado>"
    Entonces la respuesta es 422
    Y el error tiene código "invalid_transition"
    Y la historia permanece en estado "<estado_actual>"

    Ejemplos:
      | estado_actual | estado_solicitado | motivo    |
      | backlog       | en_sprint         | salto     |
      | backlog       | done              | salto     |
      | listo         | backlog           | retroceso |
      | en_sprint     | listo             | retroceso |
      | done          | en_sprint         | retroceso |

  @S-AGL-05
  Escenario: Editar campos básicos y de Cost of Delay de una historia
    Dado que existe una historia de usuario en estado "backlog" con:
      | titulo               | Cobrar pedidos pendientes |
      | prioridad            | media                     |
      | story_points         | 3                         |
      | cod_value            | 4                         |
      | cod_time_criticality | 3                         |
      | cod_risk_reduction   | 2                         |
      | cod_duration         | 3                         |
    Cuando envío una petición PATCH a /api/v1/backlog_items/1 con:
      """json
      {
        "titulo": "Cobrar pedidos pendientes (reparto)",
        "descripcion": "Incluye los pedidos del turno tarde",
        "prioridad": "alta",
        "story_points": 5,
        "cod_value": 6,
        "cod_duration": 1
      }
      """
    Entonces la respuesta es 200
    Y la historia tiene título "Cobrar pedidos pendientes (reparto)"
    Y la historia tiene descripcion "Incluye los pedidos del turno tarde"
    Y la historia tiene prioridad "alta"
    Y la historia tiene story_points 5
    Y la respuesta incluye wsjf igual a 11.0

  @S-AGL-06
  Escenario: Listar el backlog ordenado por prioridad y WSJF
    Dado que existen las siguientes historias de usuario:
      | titulo                    | prioridad | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | Torta de cumpleaños       | alta      | 8         | 5                     | 3                  | 2            |
      | Cobrar pedidos pendientes | alta      | 4         | 3                     | 2                  | 3            |
      | Reparto del turno tarde   | media     | 6         | 3                     | 3                  | 2            |
      | Inventario de harina      | baja      | 8         | 5                     | 5                  | 2            |
    Cuando envío una petición GET a /api/v1/backlog_items
    Entonces la respuesta es 200
    Y la respuesta devuelve las historias en este orden:
      | titulo                    | wsjf |
      | Torta de cumpleaños       | 8.0  |
      | Cobrar pedidos pendientes | 3.0  |
      | Reparto del turno tarde   | 6.0  |
      | Inventario de harina      | 9.0  |

# contracts:
# - POST /api/v1/backlog_items: crear historia (título, descripción, prioridad, story_points y campos CoD). Éxito 201 con BacklogItem; estado inicial "backlog"; wsjf se calcula en servidor y se devuelve en la respuesta.
# - Validaciones de frontera de creación: titulo obligatorio (no vacío), story_points entero > 0, prioridad ∈ {alta, media, baja}. Violación → 422 validation_failed.
# - PATCH /api/v1/backlog_items/:id: editar campos básicos y de Cost of Delay. Éxito 200 con BacklogItem actualizado; wsjf se recalcula y se devuelve. Campos calculados (wsjf, cod_profile) nunca se aceptan del cliente (422 readonly_field).
# - Transición de estado estricta sin saltos: backlog → listo → en_sprint → done. Salto o retroceso → 422 invalid_transition y estado persistido intacto.
# - GET /api/v1/backlog_items: listar historias ordenadas por prioridad (alta > media > baja) y, dentro de la misma prioridad, por wsjf descendente. Éxito 200.
# - Frontera módulo agile → clientes HTTP (ver contracts/agile.md): shape { "data": { ...BacklogItem } } y errores JSON API estándar.
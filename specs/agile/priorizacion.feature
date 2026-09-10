# language: es
# Contrato de negocio del módulo Priorización (WSJF / Cost of Delay + diagramas) del dominio agile.
Característica: Priorización WSJF y diagramas de Cost of Delay
  Como equipo de repostería en el workspace único (clave "REP")
  Quiero consultar el ranking WSJF, la matriz de cuadrante y el perfil CoD
  Para priorizar el backlog con el WSJF calculado en el servidor y alimentar los diagramas

  Antecedentes:
    Dado que existe un workspace único de repostería con clave "REP"
    Y que el API /api/v1/prioritization está disponible

  @S-AGL-20
  Escenario: Ranking WSJF ordenado por wsjf, prioridad e id
    Dado que existen las siguientes historias priorizadas:
      | titulo                    | estado  | prioridad | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | Torta de cumpleaños       | backlog | alta      | 8         | 5                    | 3                  | 2            |
      | Cobrar pedidos pendientes | backlog | alta      | 4         | 3                    | 5                  | 2            |
      | Reparto del turno tarde   | backlog | media     | 8         | 5                    | 3                  | 2            |
      | Inventario de harina      | backlog | baja      | 8         | 5                    | 5                  | 2            |
      | Ajustar receta            | backlog | baja      | 4         | 3                    | 5                  | 2            |
      | Sellar caja               | backlog | alta      | 6         | 3                    | 3                  | 2            |
    Cuando envío una petición GET a /api/v1/prioritization/ranking
    Entonces la respuesta es 200
    Y el ranking devuelve las historias en este orden:
      | titulo                    | wsjf | cod_profile |
      | Inventario de harina      | 9.0  | standard    |
      | Torta de cumpleaños       | 8.0  | standard    |
      | Reparto del turno tarde   | 8.0  | standard    |
      | Cobrar pedidos pendientes | 6.0  | standard    |
      | Sellar caja               | 6.0  | standard    |
      | Ajustar receta            | 6.0  | standard    |
    Y la entrada del ranking "Torta de cumpleaños" incluye los componentes CoD:
      | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | 8         | 5                    | 3                  | 2            |

  @S-AGL-21
  Esquema del escenario: Filtrar el ranking por estado
    Dado que existen las siguientes historias priorizadas:
      | titulo                    | estado    | prioridad | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | Torta de cumpleaños       | backlog   | alta      | 8         | 5                    | 3                  | 2            |
      | Cobrar pedidos pendientes | done      | media     | 4         | 3                    | 5                  | 2            |
      | Reparto del turno tarde   | en_sprint | media     | 8         | 5                    | 3                  | 2            |
    Cuando envío una petición GET a /api/v1/prioritization/ranking con estado "<estado>"
    Entonces la respuesta es 200
    Y el ranking devuelve las historias:
      | titulo           | wsjf |
      | <titulo_esperado> | <wsjf_esperado> |

    Ejemplos:
      | estado    | titulo_esperado           | wsjf_esperado |
      | done      | Cobrar pedidos pendientes | 6.0           |
      | backlog   | Torta de cumpleaños       | 8.0           |
      | en_sprint | Reparto del turno tarde   | 8.0           |

  @S-AGL-22
  Escenario: Una historia sin duración va última con wsjf 0 y perfil intangible
    Dado que existen las siguientes historias priorizadas:
      | titulo              | estado  | prioridad | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | Torta de cumpleaños | backlog | alta      | 8         | 5                    | 3                  | 2            |
      | Ajustar receta      | backlog | baja      | 1         | 1                    | 1                  | 10           |
      | Sellar caja         | backlog | alta      | 6         | 3                    | 3                  | 0            |
    Cuando envío una petición GET a /api/v1/prioritization/ranking
    Entonces la respuesta es 200
    Y el ranking devuelve las historias en este orden:
      | titulo              | wsjf | cod_profile |
      | Torta de cumpleaños | 8.0  | standard    |
      | Ajustar receta      | 0.3  | intangible  |
      | Sellar caja         | 0.0  | intangible  |

  @S-AGL-23
  Escenario: Matriz de cuadrante con duración en x y CoD total en y
    Dado que existen las siguientes historias priorizadas:
      | titulo                    | estado  | prioridad | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | Torta de cumpleaños       | backlog | alta      | 8         | 5                    | 3                  | 2            |
      | Cobrar pedidos pendientes | done    | media     | 4         | 3                    | 2                  | 3            |
      | Reparto del turno tarde   | listo   | alta      | 12        | 8                    | 10                 | 1            |
    Cuando envío una petición GET a /api/v1/prioritization/matriz
    Entonces la respuesta es 200
    Y la matriz de cuadrante contiene los puntos:
      | titulo                    | x | y  | tamano | cod_profile |
      | Torta de cumpleaños       | 2 | 16 | 8.0    | standard    |
      | Cobrar pedidos pendientes | 3 | 9  | 3.0    | intangible  |
      | Reparto del turno tarde   | 1 | 30 | 30.0   | expedite    |

  @S-AGL-24
  Escenario: Perfil CoD agrupado en expedite, fixed_date, standard e intangible
    Dado que existen las siguientes historias priorizadas:
      | titulo                    | estado  | prioridad | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | Torta de cumpleaños       | backlog | alta      | 12        | 8                    | 10                 | 1            |
      | Cobrar pedidos pendientes | backlog | media     | 2         | 8                    | 1                  | 4            |
      | Reparto del turno tarde   | backlog | media     | 6         | 3                    | 3                  | 2            |
      | Ajustar receta            | backlog | baja      | 1         | 1                    | 1                  | 10           |
    Cuando envío una petición GET a /api/v1/prioritization/perfil
    Entonces la respuesta es 200
    Y el perfil CoD agrupa las historias:
      | perfil     | historias                 |
      | expedite   | Torta de cumpleaños       |
      | fixed_date | Cobrar pedidos pendientes |
      | standard   | Reparto del turno tarde   |
      | intangible | Ajustar receta            |

  @S-AGL-25
  Escenario: El ranking es de solo lectura y el WSJF siempre lo calcula el servidor
    Dado que existen las siguientes historias priorizadas:
      | titulo              | estado  | prioridad | cod_value | cod_time_criticality | cod_risk_reduction | cod_duration |
      | Torta de cumpleaños | backlog | alta      | 8         | 5                    | 3                  | 2            |
    Cuando envío una petición GET a /api/v1/prioritization/ranking con el parámetro wsjf "999"
    Entonces la respuesta es 200
    Y el ranking devuelve para "Torta de cumpleaños" un wsjf igual a 8.0

# contracts:
# - GET /api/v1/prioritization/ranking: ranking de solo lectura. Query opcional ?estado= (backlog|listo|en_sprint|done). Éxito 200 con { "data": [RankingEntry] }.
#   RankingEntry = { id, titulo, prioridad, estado, cod_value, cod_time_criticality, cod_risk_reduction, cod_duration, wsjf, cod_profile }.
#   Orden: wsjf desc; empate → prioridad (alta > media > baja); nuevo empate → id asc.
# - Bordes del ranking: wsjf = (cod_value + cod_time_criticality + cod_risk_reduction) / cod_duration, calculado en servidor.
#   cod_duration = 0 → wsjf = 0 y cod_profile = "intangible" (sin división por cero) y la historia va al final del ranking.
#   El cliente nunca inyecta wsjf: el endpoint es de solo lectura y el valor devuelto es siempre el calculado.
# - GET /api/v1/prioritization/matriz: datos del diagrama de burbujas de cuadrante. Éxito 200 con { "data": [MatrizPoint] }.
#   MatrizPoint = { titulo, x: cod_duration (duración/complejidad), y: cod_value + cod_time_criticality + cod_risk_reduction (CoD total), tamano: wsjf, cod_profile }.
#   Incluye TODAS las historias del backlog, sin filtrar por estado.
# - GET /api/v1/prioritization/perfil: agrupación por cod_profile. Éxito 200 con { "data": { expedite: [RankingEntry], fixed_date: [RankingEntry], standard: [RankingEntry], intangible: [RankingEntry] } }.
# - cod_profile ∈ { expedite, fixed_date, standard, intangible }: expedite si wsjf >= 20; fixed_date si cod_time_criticality >= 8; standard si wsjf >= 5; intangible en el resto (incluye cod_duration = 0). Regla ya vigente en BacklogItem.
# - Frontera módulo priorización → módulo backlog: consume BacklogItem (ver contracts/agile.md) solo para lectura, no escribe. Frontera → clientes HTTP: shape { "data": ... } y errores JSON API estándar.

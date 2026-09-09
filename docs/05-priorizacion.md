# Priorización: Cost of Delay + WSJF

## Método

Cada item del backlog puntúa 3 componentes del **Cost of Delay** (escala 1–13):

| Componente | Pregunta |
|---|---|
| Valor de negocio | ¿Cuánto beneficio/valor aporta? |
| Criticidad temporal | ¿Se deprecia el valor con el tiempo? |
| Reducción de riesgo / oportunidad | ¿Reduce riesgo o habilita algo más? |

**WSJF = (valor + criticidad + riesgo) ÷ duración**

Mayor WSJF = mayor prioridad. Duración en story points/días (job size).

## Perfil CoD (Reinertsen)

| Perfil | Definición |
|---|---|
| `expedite` | CoD altísimo y urgencia máxima → va primero siempre |
| `fixed_date` | fecha límite dura → se programa hacia atrás |
| `standard` | cola normal, prioriza por WSJF |
| `intangible` | CoD bajo, posponible → último |

## Diagramas (pantallas del sistema)

1. **Ranking WSJF**: tabla ordenable por WSJF con componentes y duración.
2. **Matriz de cuadrante** (burbujas): x = duración, y = valor CoD, tamaño = WSJF.
3. **Perfil CoD**: clasificación de items en expedite/fixed_date/standard/intangible.

## Aplicado a la DB

Campos en `backlog_items`: `cod_value`, `cod_time_criticality`,
`cod_risk_reduction`, `cod_duration`; `wsjf` y `cod_profile` calculados por
`PrioritizationService` (DOP). Endpoint `/api/v1/prioritization` devuelve el
ranking y coordenadas para los diagramas.

## Aplicado al MVP

Puntajes propuestos (calibrables en la herramienta) y orden de construcción
reconciliado con dependencias:

| Módulo | Valor | Criticid. | Riesgo | CoD | Dur | WSJF | Orden |
|---|---|---|---|---|---|---|---|
| Priorización (WSJF+diagramas) | 5 | 8 | 5 | 18 | 5 | 3.6 | 4 |
| Burndown + velocity | 8 | 13 | 5 | 26 | 8 | 3.3 | 3 |
| Backlog (historias) | 5 | 8 | 3 | 16 | 5 | 3.2 | 1 |
| Sprints + daily snapshots | 8 | 13 | 3 | 24 | 8 | 3.0 | 2 |
| Ventas/Pedidos | 8 | 8 | 3 | 19 | 8 | 2.4 | 8 |
| Clientes | 3 | 2 | 2 | 7 | 3 | 2.3 | 7 |
| Productos/Recetas | 8 | 5 | 3 | 16 | 8 | 2.0 | 6 |
| Producción | 8 | 5 | 3 | 16 | 8 | 2.0 | 9 |
| Kanban + gates | 5 | 5 | 5 | 15 | 8 | 1.9 | 10 |
| GitFlow | 3 | 3 | 8 | 14 | 8 | 1.8 | 11 |
| Inventario/insumos | 8 | 5 | 5 | 18 | 13 | 1.4 | 5 |
| Reportes ERP + Dashboard | 8 | 3 | 3 | 14 | 13 | 1.1 | 12 |

Nota: el dominio ágil entra primero (máxima criticidad temporal y pedido
explícito); el ERP después siguiendo su cadena de dependencias
(inventario → productos → clientes/ventas → producción).
# Proceso ágil burocrático

El objetivo es que la metodología ágil **se sienta como burocracia**: cada
ceremonia tiene artefactos, cada avance tiene gates y todo queda trazado.

## Ceremonias con artefactos

1. **Planificación de sprint**: formulario que crea el `sprint` (fechas,
   objetivo) y mueve items del backlog a `en_sprint`. Queda registrado el
   compromiso en points.
2. **Daily**: registro diario obligatorio por día hábil del sprint → crea un
   `daily_snapshot` (puntos y horas restantes). **Faltar el daily marca un
   hueco en el burndown** con aviso "sin reporte".
3. **Sprint review/retro**: `sprint_reviews` con notas, velocidad lograda y
   observaciones.
4. **Cierre de sprint**: bloqueado si quedan tareas sin `done`. Genera métricas
   (completado vs comprometido).

## Gates de estado (no saltables)

```
todo → in_progress → review → done
```

| Transición | Gate |
|---|---|
| `todo → in_progress` | exige rama creada (`git_branch` en la tarea) |
| `in_progress → review` | exige PR abierto (`git_pr`) |
| `review → done` | exige PR mergeado + Definition of Done marcado |

## Burndown chart (regla de negocio)

- **Línea ideal**: `restante = total_puntos − (total_puntos / días_sprint) × día`.
  Desde el inicio hasta 0 el último día.
- **Línea real**: suma de puntos/horas restantes por `daily_snapshot`.
- **Scope change**: si entran items al sprint a mitad, la línea ideal se
  recalcula desde ese día.
- **Días sin daily**: hueco en la línea real + marcador "sin reporte".
- Se calcula en **story points**; las horas son el detalle del daily.

## Velocity

Puntos cerrados por sprint (promedio y tendencia) → alimenta la planificación.

## Burocracia deliberada (resumen)

- Estados que no se saltan, con gates de git.
- Daily obligatorio (faltarlo queda visible en el burndown).
- Cierre de sprint bloqueado con tareas abiertas.
- Definition of Done como checklist obligatorio.
- Sprint report imprimible (completado/comprometido + velocidad).
- Release con sign-off (ver gitflow).
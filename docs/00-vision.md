# Visión del producto

## Problema

Una repostería necesita operar su día a día (inventario, recetas, producción,
ventas) y, a la vez, el equipo de desarrollo que construye ese sistema necesita
un proceso ágil que **se sienta burocrático**: métricas visibles, gates de
proceso y trazabilidad, no solo un tablero de tareas.

## Solución

Monolito modular con dos dominios fuertemente separados:

1. **Dominio Repostería (ERP)** — la operación del negocio.
2. **Dominio Ágil** — el proceso Scrum del equipo, con burndown chart como
   pieza central y priorización WSJF/Cost of Delay.
3. **GitFlow** — la política de repositorio enlazada al estado de las tareas.

## Principios

- KISS. Monolito modular, DDD minimalista.
- DOP y programación funcional sobre POO.
- Burocracia deliberada en el proceso ágil: estados no saltables, daily
  obligatorio, cierre de sprint bloqueado, Definition of Done obligatorio,
  release con sign-off.
- Los diagramas y la priorización no son "slides": son datos en la DB y
  pantallas del sistema.

## Stakeholders

- **Dueña de la repostería**: usa el ERP (inventario, producción, ventas, reportes).
- **Equipo de desarrollo**: usa el módulo ágil (sprints, burndown, priorización).
- **Admin (rol)**: configura y cierra sprints/releases.
- **Operador (rol)**: opera el día a día (registra ventas, producción, daily).
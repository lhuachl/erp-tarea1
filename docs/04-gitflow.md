# GitFlow

## Modelo de ramas

```
main (producción, tags vX.Y.Z)
 ├─ develop (integración)
 │   ├─ feature/REP-<id>-slug   ← una por tarea, desde develop
 │   └─ release/vX.Y.Z           ← desde develop → main + develop
 └─ hotfix/vX.Y.Z                ← desde main → main + develop
```

| Rama | Propósito | Merge a |
|---|---|---|
| `main` | producción, solo releases | — |
| `develop` | integración continua de features | `main` (vía release) |
| `feature/REP-<id>-slug` | una tarea del backlog | `develop` |
| `release/vX.Y.Z` | estabilización y versionado | `main` + `develop` |
| `hotfix/vX.Y.Z` | fix urgente en producción | `main` + `develop` |

## Commits convencionales

Formato: `tipo(alcance): descripción`.

- Tipos: `feat|fix|docs|chore|build|refactor|style|test|perf|revert|ci`.
- Alcance: módulo (`agile`, `inventario`, `ventas`, ...) o id de tarea (`REP-12`).
- Hook `hooks/commit-msg` valida el formato sin dependencias
  (`bin/install-hooks`).

## Tarea ↔ Git (gates)

El estado de una `sprint_task` avanza según su estado en git:

1. `todo → in_progress`: se crea la rama `feature/REP-<id>-slug` → se registra
   en `git_branch`.
2. `in_progress → review`: se abre PR hacia `develop` → se registra en `git_pr`.
3. `review → done`: el PR se mergea + Definition of Done completo.

## Release (script `bin/release`)

- Solo desde un sprint `cerrado`.
- Bump de versión **semver** (`major.minor.patch`).
- Genera/actualiza `CHANGELOG.md` desde los conventional commits.
- Tag `vX.Y.Z` en `main`.
- Checklist de sign-off antes de taggear.

## Estructura de commits esperada (granular)

```
docs: definir modelo de datos
feat(inventario): crear materiales y movimientos de stock
test(inventario): cubrir escenario @S-REP-05
fix(agile): recalcular linea ideal ante scope change
build: agregar vite_rails y mantine
```

Commits atómicos: uno por unidad lógica; test y feature pueden ir juntos solo si
son atómicos a la feature; las correcciones de review van como `fix(...)`.
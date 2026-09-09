# ERP Repostería + Gestión Ágil (Burndown)

Sistema integral para una repostería con dos dominios en un solo monolito modular:

- **A. ERP Repostería**: clientes, insumos/inventario, productos y recetas (BOM), producción, ventas/pedidos y reportes.
- **B. Gestión ágil (Scrum burocrático)**: backlog, sprints, tareas, daily updates, **burndown chart**, velocity, sprint reports, priorización WSJF/Cost of Delay y gates de proceso.
- **C. GitFlow**: política de ramas, commits convencionales, releases semver y changelog, enlazada al estado de las tareas.

## Documentación

La planificación vive en [`docs/`](docs/), versionada. Los artefactos generados
(HTML/PDF) se construyen con `bin/docs-build` y NO se versionan (`docs/out/`).

## Convenciones de repo

- **Commits convencionales** obligatorios (hook `hooks/commit-msg`, instalar con `bin/install-hooks`).
- **GitFlow**: `main` (producción, tags) + `develop` (integración) + `feature/REP-<id>-slug` + `release/vX.Y.Z` + `hotfix/vX.Y.Z`.
- Desarrollo guiado por specs: ver `docs/06-roadmap-mvp.md` y el pipeline en `docs/07-pipeline-sdd.md`.

## Stack

Rails 8.1 · PostgreSQL (Supabase) · Vite + React + Mantine · Devise (roles admin/operador) · RSpec + cucumber-rails + mutant.

## Setup

```sh
cp .env.example .env   # completar DATABASE_URL de Supabase
./bin/install-hooks
bundle install
npm install
DATABASE_URL="$DATABASE_URL_MIGRATE" bin/rails db:prepare
RAILS_ENV=test DATABASE_URL="$DATABASE_URL_MIGRATE" bin/rails db:schema:load
bin/dev
```

> Nota: los tests corren sobre el mismo database de Supabase pero aislados en el
> schema `test` (`schema_search_path`). Nunca se dropea la base; las tablas
> `test.*` son independientes de `public.*`.
# Stack tecnológico

| Capa | Elección | Notas |
|---|---|---|
| Backend | Ruby on Rails 8.1 | Ruby 4.0.6, modo full-stack |
| Base de datos | PostgreSQL | Supabase como provider (cloud) |
| Conexión DB | `DATABASE_URL` | Env var, nunca versionada |
| Pooler Supabase | Transaction pooler (5432) | `prepared_statements: false`; migraciones por session pooler (6543) |
| Frontend | Vite (`vite_rails`) + React + Mantine UI | SPA, react-router |
| API | JSON bajo `/api/v1` | Consumida por el SPA |
| Autenticación | Devise | Roles: `admin`, `operador` (enum + helpers, sin Pundit por ahora) |
| Testing | RSpec + cucumber-rails | Gherkin en español, ejecutable (runner BDD) |
| Mutación | mutant | Umbral ~80% de mutation score |
| GitFlow | Política de ramas + hook commit-msg | Conventional commits |

## Decisiones clave

- **Rails full-stack + vite_rails**: un solo deploy; Vite integrado al asset
  pipeline de Rails. El SPA React monta sobre la raíz y consume `/api/v1`.
- **Supabase desde el inicio**: dev/test y producción usan la misma nube de
  Postgres vía `DATABASE_URL`.
- **Sin Pundit en el MVP**: la autorización se resuelve con enum de rol +
  helpers de controlador; se escala si crece.
- **Gherkin como test ejecutable**, no documentación pasiva.

## Tooling de docs

- Markdown versionado en `docs/`.
- HTML + PDF generados con `marked` + `puppeteer-core` (chromium del sistema)
  vía `bin/docs-build`. Artefactos en `docs/out/` (gitignored).
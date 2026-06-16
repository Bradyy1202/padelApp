# Pádel App (estilo DUPR) — Monorepo

Red de rating y organización de pádel para Costa Rica. Mide el nivel real de cada
jugador a partir de partidos verificados y construye rankings, pozos y torneos sobre
ese rating. Ver el documento de producto en [PRD_Padel_App.md](PRD_Padel_App.md) y el
plan de desarrollo por sprints.

## Stack

| Capa | Tecnología |
|---|---|
| App móvil | Flutter (Riverpod, GoRouter, Dio, Supabase, secure storage) |
| Backend de negocio | NestJS + Prisma |
| Datos / Auth / Storage / Realtime | Supabase / PostgreSQL |
| Colas (rating, notificaciones) | Redis + BullMQ |
| Push / Analítica | FCM · PostHog |

**Frontera de seguridad (PRD §9.2):** toda mutación sensible (rating, confirmación de
partidos, QR, merge, pozos/torneos) pasa por NestJS con `service_role`. La app lee datos
públicos vía Supabase con RLS; para escribir, llama a NestJS.

## Estructura

```
apps/
  backend/   NestJS (lógica de negocio, Prisma)
  mobile/    Flutter (iOS/Android) — capas presentation/state/domain/data/core (§9.3)
packages/    código compartido (futuro)
infra/
  docker/    docker-compose local (Postgres + Redis)
  supabase/  políticas RLS (rls_policies.sql) — aplicar en Supabase
.github/workflows/  CI (backend + mobile)
```

## Requisitos

- Node.js ≥ 20 y pnpm ≥ 9
- Flutter (stable) y Dart
- Docker Desktop (para Postgres/Redis locales)
- git

## Setup local

### 1. Infraestructura (Postgres + Redis)

> Requiere Docker Desktop **iniciado**. En su primer arranque, abre la app de Docker
> Desktop, acepta los términos y deja que configure WSL2 (puede pedir reinicio).

```powershell
pnpm infra:up        # docker compose up -d (postgres + redis)
```

### 2. Backend

```powershell
cd apps/backend
copy .env.example .env          # ajustar credenciales de Supabase
pnpm install                    # (o pnpm install en la raíz del monorepo)
pnpm exec prisma migrate deploy # aplica las migraciones a Postgres
pnpm start:dev                  # http://localhost:3000/api/v1
```

Verifica: `GET http://localhost:3000/api/v1/health` → `{ "status": "ok", ... }`.

Aplica las políticas RLS en tu proyecto Supabase con
[infra/supabase/rls_policies.sql](infra/supabase/rls_policies.sql).

### 3. App móvil

```powershell
cd apps/mobile
flutter pub get
flutter run `
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 `
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

> En el emulador Android, `10.0.2.2` apunta al `localhost` del host. En iOS usa `localhost`.

## Scripts útiles (raíz)

| Comando | Acción |
|---|---|
| `pnpm infra:up` / `pnpm infra:down` | Levanta/baja Postgres + Redis |
| `pnpm backend:dev` | Backend en modo watch |
| `pnpm backend:test` | Tests del backend |
| `pnpm prisma:migrate` | `prisma migrate dev` |
| `pnpm prisma:generate` | Regenera el cliente Prisma |

## Estado del proyecto

**Sprint 0 (Fundaciones) — en curso.** Monorepo, scaffold NestJS con `/health`,
esquema Prisma completo (§10) con migraciones (índices, `mv_rankings`, RLS), app Flutter
con estructura de capas y CI. Siguiente: Sprint 1 (Identidad y perfil).

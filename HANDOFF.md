# Handoff — Pádel App (estado para continuar)

> Documento para retomar el trabajo. Última actualización: cierre del **Sprint 3**.
> Repo: https://github.com/Bradyy1202/padelApp · rama `main` · último commit `c183431`.

## 1. Resumen de dónde vamos

MVP por sprints (roadmap PRD §19). **Completados 0–3** (núcleo de rating confiable):

| Sprint | Estado |
|---|---|
| 0 — Fundaciones (monorepo, NestJS, Prisma, Flutter, docker, CI, /health) | ✅ |
| 1 — Identidad y perfil (auth, onboarding, invitados, merge/claim, borrado) | ✅ |
| 2 — Partidos + QR (crear, QR firmado, unirse, marcador validado) | ✅ |
| 3 — Confirmación + Rating (mayoría/admin/24h, Glicko-2 dobles+MOV, BullMQ, recálculo en merge) | ✅ |
| 4 — Rankings + perfil estadístico | ⬜ **SIGUIENTE** |
| 5 — Notificaciones + Moderación | ⬜ |
| 6 — Pozos | ⬜ |
| 7 — Torneos | ⬜ |
| 8 — Hardening + Lanzamiento | ⬜ |

Extra hecho: rediseño UI móvil con la skill **UI/UX Pro Max** (solo `apps/mobile`, ver [CLAUDE.md](CLAUDE.md)).

## 2. Requisitos de entorno (Windows)

- Node ≥ 20, **pnpm**, **Flutter** (en `C:\Users\zumba\flutter`), **Docker Desktop** (WSL2), git.
- Refrescar PATH en cada terminal nueva si algo "no se encuentra".

## 3. Cómo levantar todo (orden importa)

```powershell
# 1) Infra (Docker Desktop debe estar ABIERTO y "Engine running")
pnpm infra:up                       # Postgres + Redis (docker compose)

# 2) Backend (NestJS) — http://localhost:3000/api/v1
cd apps/backend
pnpm install                        # si es primera vez
pnpm exec prisma migrate deploy     # aplica migraciones
pnpm start:dev                      # o: node dist/main.js (tras pnpm build)
# Verificar: GET http://localhost:3000/api/v1/health -> {"status":"ok"}

# 3) App Flutter (web, para probar rápido)
cd apps/mobile
C:\Users\zumba\flutter\bin\flutter.bat run -d edge --web-port=5000 ^
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

> **Si la app muestra `DioException [connection error]`**: casi siempre es que Docker Desktop
> se cerró → Postgres/Redis abajo → backend sin DB. Abre Docker, `pnpm infra:up`, reinicia el
> backend y refresca la app.

## 4. Modo desarrollo sin Supabase (clave para probar)

No hay proyecto Supabase configurado todavía. Para probar sin login real:
- Backend acepta el header **`x-dev-user-id: <uuid>`** como usuario autenticado
  (flag `AUTH_DEV_BYPASS=true` en `apps/backend/.env`, **solo dev**).
- La app, sin credenciales Supabase, muestra el botón **"Entrar en modo desarrollo"**
  (usa el uuid fijo `11111111-1111-1111-1111-111111111111`).
- Usuarios de prueba ya creados en la BD local: `1111...1111` (Andres Zumbado) y
  `2222...2222` (Rival Real).

## 5. Tests

```powershell
cd apps/backend; pnpm test          # 27 unit (rating Glicko-2, marcador, validaciones)
cd apps/mobile;  C:\Users\zumba\flutter\bin\flutter.bat test
```

## 6. Arquitectura rápida

- **Frontera (PRD §9.2):** toda mutación sensible va por NestJS (`service_role`). La app
  lee/escribe vía la API; Supabase para auth/realtime/storage cuando se configure.
- **Backend** `apps/backend/src/`: `auth` (guards JWT+roles), `users` (perfil/invitados/merge),
  `matches` (partidos/QR/confirmación/cron descarte), `rating` (Glicko-2 + cola BullMQ),
  `supabase`, `prisma`, `common`, `health`.
- **App** `apps/mobile/lib/`: capas `presentation/ state/ domain/ data/ core/` (Riverpod,
  GoRouter con guard, Dio con interceptor de auth/dev).
- **Rating**: al confirmarse un partido → `RatingQueue.enqueueMatch` → `RatingProcessor`
  (worker BullMQ) → `RatingService.applyMatch` escribe `rating_current` + `rating_history`.
  ⚠️ El `jobId` de BullMQ NO admite `:` (usar `match-<id>`).

## 7. SIGUIENTE: Sprint 4 — Rankings + perfil estadístico

Plan concreto (ya hay base en la BD: vista materializada `mv_rankings` creada en migración
`20260615000100_indexes_view`).

**Backend (nuevo módulo `rankings/`):**
1. `GET /players/:id/rating` y `GET /players/:id/rating/history` (leer `rating_current` /
   `rating_history`). *(Hoy el rating se ve embebido en `GET /me`.)*
2. `GET /rankings?scope=global|country|city|club|gender&value=…&page&limit` leyendo de
   `mv_rankings` (solo `ESTABLISHED`).
3. Job de refresco: `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rankings` cada 5–15 min
   (usar `@nestjs/schedule`, ya instalado; ejecutar SQL crudo con Prisma `$executeRaw`).
4. Tests del servicio de rankings.

**App Flutter:**
1. Pantalla de **Rankings** con filtros (ámbito) — lista paginada.
2. **Perfil estadístico**: historial V/D y **evolución del rating** (gráfico de
   `rating_history`). Para gráficos, `ui-ux-pro-max` tiene guía de charts (Flutter: `fl_chart`).
3. Enlazar desde el Home.

**Verificación e2e:** crear varios partidos confirmados entre 2 usuarios dev, refrescar
`mv_rankings`, y comprobar que `GET /rankings` y la pantalla muestran el orden por rating.

## 8. Pendientes transversales (no bloquean Sprint 4)

- **Credenciales Supabase reales** (login Google/Apple, foto a Storage bucket `avatars`,
  borrado en Auth, aplicar `infra/supabase/rls_policies.sql`). Hoy: modo dev.
- **Escaneo QR por cámara** (`mobile_scanner`) — solo en build de dispositivo; en web se usa
  el código corto manual.
- **Deploy a staging** (Fly.io/Render + Redis gestionado) — Sprint 8.
- Avisos `LF→CRLF` de git en Windows: inofensivos (se puede añadir `.gitattributes` con
  `* text=auto eol=lf` para silenciarlos).

## 9. Git / push

Remoto ya configurado (`origin`). Para subir cambios:
```powershell
git add .
git commit -m "..."
git push origin main
```
Los secretos (`.env`) están en `.gitignore` y no se suben.

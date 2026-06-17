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
| 4 — Rankings + perfil estadístico (mv_rankings+scopes, /rankings, rating/history, app rankings + gráfico evolución) | ✅ |
| 5 — Notificaciones + Moderación (in-app + FCM stub, admin disputas/roles + audit_log, PostHog opcional) | ✅ |
| 6 — Pozos (emparejamiento balanceado fijas/rotación, rondas, standings, cierre→rating; app lista/detalle) | ✅ |
| 7 — Torneos | ⬜ **SIGUIENTE** |
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

## 7. SIGUIENTE: Sprint 7 — Torneos

Tablas ya existen (`tournaments`, `tournament_categories`, `tournament_registrations`,
`tournament_matches`).

**Backend (nuevo `TournamentsModule`, endpoints PRD §11.5, mutaciones @Roles(administrador)):**
1. `POST /tournaments` (crear: nombre, formato SINGLE_ELIM|ROUND_ROBIN, fechas).
2. `POST /tournaments/:id/categories` (nombre, género M/F/MIXED/OPEN, min/max rating).
3. `POST /tournaments/:id/register` (inscribir pareja: player1+player2 en una categoría;
   validar rango de rating/género).
4. `POST /tournaments/:id/generate` → seed por rating; **bracket** potencia de 2 con byes
   (eliminación) o **fixture round-robin** por categoría. Servicio puro testeable.
5. `POST /tournament-matches/:id/result` → registra y **avanza** el bracket (rellena
   `next_match_id`) o actualiza la tabla round-robin.
6. `GET /tournaments/:id` (estado + brackets/fixture). Al finalizar: partidos → rating
   (origen TOURNAMENT) con `RatingQueue.enqueueMatch`.

**App Flutter:** crear torneo + categorías, inscripción, ver bracket/fixture, registrar
resultados (admin).

**Patrón a reutilizar:** calca la estructura de `pozos/` (servicio puro de generación +
`PozosService` orquestando matches + cierre→rating). El avance de bracket y la generación
con byes es la lógica nueva crítica (tests como `pozo-pairing.service.spec.ts`).

**Sprint 6 (hecho), referencia:** `pozos/` con emparejamiento balanceado (`PozoPairingService`),
rondas que crean `matches` (type POZO), standings, y `close` que confirma+encola rating.
Recuerda: matches de pozo/torneo NO pasan por confirmación individual (heredan del organizador).

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

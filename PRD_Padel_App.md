# PRD — Aplicación Móvil de Pádel (estilo DUPR)
### Product Requirements Document · Versión 1.0 · Junio 2026

> Documento orientado **exclusivamente al desarrollo del producto**. No incluye monetización, pricing, CAC/LTV ni marketing.
> Stack: **Flutter** (app) · **NestJS** (backend de negocio) · **Supabase / PostgreSQL** (datos, auth, storage, realtime).
> Mercado de lanzamiento: **Costa Rica** · Idioma: **Español** (código i18n-ready) · Equipo: **2–3 personas**.

---

## Decisiones de discovery consolidadas (baseline del PRD)

| Tema | Decisión final |
|---|---|
| Arquitectura | Flutter + Supabase (Postgres/Auth/Storage/Realtime) + NestJS (lógica de negocio) |
| Rating | Algoritmo propio basado en **Glicko-2 adaptado a dobles + margen de marcador**, mostrado en escala 1.0–7.0 |
| Confidence | Derivado de la desviación del rating (RD). 0–100 % |
| Fair Play Score | **Eliminado** del producto |
| Roles | `jugador` (default) y `administrador` (asignado manualmente) |
| Login MVP | Email, Google, Apple (Teléfono → V1 por costo de SMS) |
| Jugadores invitados | **Sí** — placeholders reclamables |
| Offline | **No** — solo online con reintentos |
| Confirmación resultado | Mayoría de jugadores **o** admin; ventana 24 h; sin auto-aprobación (se descarta) |
| Pozos | Parejas fijas o rotación; clasificación por partidos ganados; desempate por diferencia de games; empates permitidos |
| Torneos | Eliminación simple + round-robin; categorías por nivel y género |
| Notificaciones | FCM (push) + in-app |
| Analítica | PostHog Cloud |
| Edad mínima | 12 años |
| Escala objetivo | Diseño para 100k usuarios; infra inicial ~10k |

**Alcance MVP confirmado:** Núcleo (perfil, partidos, QR, rating, confidence) → Rankings → Pozos → Torneos.
**Fuera del MVP:** Matchmaking, Americanos, Rey de cancha, Retos/Ladder, Compatibilidad de parejas, Gamificación, Teléfono como login.

---

## 1. Executive Summary

La aplicación es una **red de rating y organización de pádel** para Costa Rica, inspirada en DUPR. Su función central es **medir el nivel real de cada jugador** a partir de partidos verificados y mantener **rankings confiables**, sobre los cuales se construyen herramientas de organización de juego: **pozos** y **torneos**.

El producto resuelve tres problemas concretos del ecosistema amateur/semipro de pádel:

1. **No existe una medida objetiva de nivel.** Hoy el nivel se autodeclara ("soy 4ta", "soy intermedio-alto") y es inconsistente entre clubes. La app calcula un rating dinámico a partir de resultados reales.
2. **El registro de resultados no es confiable.** Sin verificación, cualquiera puede inflar su nivel. La app usa **validación por QR + confirmación por mayoría o administrador**.
3. **Organizar juego equilibrado es manual y tedioso.** Pozos y torneos se gestionan hoy en papel o WhatsApp. La app automatiza rotaciones, emparejamientos, tablas y brackets, y conecta los resultados directamente al rating.

La aplicación es **multiplataforma (Android + iOS)** desde una única base de código Flutter, con un backend NestJS que concentra toda la lógica sensible (rating, validación, anti-fraude) y Supabase como capa de datos/identidad gestionada para minimizar costo operativo de un equipo pequeño.

El documento está diseñado para que diseño pueda iniciar wireframes, Flutter y NestJS puedan desarrollar en paralelo, QA pueda escribir planes de prueba y DevOps pueda desplegar.

---

## 2. Product Vision

**Visión:** Ser el estándar de medición de nivel de pádel en Costa Rica, de modo que decir "mi rating es 3.7" signifique lo mismo en cualquier club del país.

**Objetivos de producto (no de negocio):**

- **O1 — Medición confiable:** que el rating refleje el nivel real con un margen de error explícito (confidence). Un jugador con muchos partidos verificados tiene un rating en el que se puede confiar.
- **O2 — Integridad de datos:** que sea difícil manipular el rating (cuentas falsas, resultados inventados, palizas amañadas). La confianza del sistema depende de esto.
- **O3 — Reducción de fricción:** registrar un partido y confirmarlo debe tomar segundos, no minutos. El QR es el mecanismo central.
- **O4 — Organización automatizada:** que un organizador pueda correr un pozo o un torneo de principio a fin desde el teléfono, con tablas en tiempo real.
- **O5 — Crecimiento de la red:** que la app funcione aun cuando la mayoría de jugadores todavía no la tienen, mediante **jugadores invitados reclamables**.

**No-objetivos (explícitos):** No es una red social, no es marketplace de canchas, no es reservas de pista, no gestiona pagos. Estas funciones quedan fuera del alcance del producto descrito.

---

## 3. Product Scope

El alcance se divide en MVP, V1, V2, V3. La regla de corte fue: **el MVP solo incluye lo necesario para que el rating sea confiable y para que un club pueda operar su juego organizado básico.**

### MVP (primer release a producción)

**Identidad y perfil**
- Registro/login con Email, Google, Apple.
- Perfil: nombre, foto, ciudad, club, mano dominante, lado favorito, nivel estimado inicial.
- Jugadores invitados (placeholder) creados por otros, reclamables al registrarse.

**Partidos y rating**
- Crear partido (amistoso/competitivo) con 2–4 jugadores.
- Validación por **QR** (escaneo para unirse) + registro de resultado.
- Confirmación por mayoría o por administrador, ventana 24 h.
- **Rating dinámico + Confidence** con algoritmo propio (Glicko-2 adaptado a dobles + margen).
- Historial de partidos y evolución de rating.

**Rankings**
- Global, país (CR), ciudad, club, género. (Por edad → V1, requiere fecha de nacimiento obligatoria.)

**Pozos**
- Crear pozo con parejas fijas o rotación.
- Generación de rondas y emparejamientos balanceados por rating.
- Tabla en tiempo real (Supabase Realtime).
- Clasificación por partidos ganados, desempate por diferencia de games.
- Al cerrar el pozo, los partidos alimentan el rating.

**Torneos**
- Eliminación simple y round-robin.
- Categorías por nivel y género.
- Inscripción, brackets, registro de resultados, clasificación.
- Resultados alimentan el rating.

**Transversal**
- Notificaciones push (FCM) + in-app.
- Panel administrativo básico (web o vista admin en la app) para aprobar resultados, gestionar reportes y asignar rol `administrador`.
- Borrado de cuenta (cumplimiento Ley 8968).

### V1

- **Login por teléfono** (SMS OTP).
- **Matchmaking:** encontrar jugadores por nivel, distancia, disponibilidad y tipo de juego.
- **Americanos:** rotación automática e individuales, ranking en vivo.
- Ranking por edad (requiere captura de fecha de nacimiento).
- Estadísticas avanzadas (rachas, rendimiento por horario, rendimiento por pareja).
- **Compatibilidad de parejas** (historial conjunto, % victorias).

### V2

- **Rey de cancha** (gestión de rondas y movimiento entre canchas).
- **Retos / Ladder** entre jugadores.
- **Gamificación** (logros, medallas, hitos).
- Panel de club avanzado (gestión de canchas, calendario de eventos).
- Rating de **singles** independiente del de dobles.

### V3

- Federación de ranking nacional / integración con clubes y ligas oficiales.
- Modelo de rating V3 (ver §12): incorporación de tiempo de juego, calidad del oponente ponderada, anti-inflación regional.
- Expansión geográfica (multi-país) con normalización de ratings cross-región.
- API pública / webhooks para clubes y terceros.

---

## 4. User Roles

Por decisión de discovery, el sistema tiene **dos roles** persistidos en base de datos en un campo `role`. La granularidad fina (organizador, moderador) se modela como **permisos derivados del rol + propiedad del recurso**, no como roles separados.

| Rol | Asignación | Permisos clave |
|---|---|---|
| **jugador** | Por defecto al registrarse | Editar su perfil, crear/unirse a partidos, confirmar/disputar resultados, ver rankings, inscribirse en pozos/torneos, reclamar perfil invitado. |
| **administrador** | Asignado manualmente por el equipo de plataforma (típicamente a clubes) | Todo lo de jugador + crear y gestionar pozos/torneos, aprobar/forzar resultados, resolver disputas, gestionar reportes, crear jugadores invitados en masa, ver panel admin. |

**Actores no-rol (entidades del dominio):**

- **Jugador invitado (guest):** no es una cuenta; es un registro de jugador sin `user_id`, creado por otro para poder armar partidos. Tiene rating propio. Al registrarse una persona, puede **reclamar** ese registro (merge de identidad).
- **Club:** entidad de datos (no un rol). Un club tiene un perfil reclamable; cuando una persona del club obtiene rol `administrador`, queda vinculada como gestora de ese club.

**Concepto de "organizador":** es cualquier usuario `administrador` que **es dueño** (`owner_id`) de un pozo o torneo. La autorización combina `role = administrador` **y** propiedad del recurso (o pertenencia al club organizador).

---

## 5. User Stories

Formato: *Como [usuario] quiero [acción] para [beneficio].*

**Identidad / Perfil**
- US-01 — Como jugador nuevo, quiero registrarme con Google/Apple/Email para empezar a usar la app sin fricción.
- US-02 — Como jugador, quiero completar mi perfil (mano, lado, club, nivel estimado) para que el sistema me ubique mejor.
- US-03 — Como jugador, quiero reclamar un perfil que alguien creó por mí para no perder los partidos ya jugados ni mi rating acumulado.
- US-04 — Como jugador, quiero borrar mi cuenta y mis datos para ejercer mi derecho de protección de datos.

**Partidos / Rating**
- US-05 — Como jugador, quiero crear un partido y generar un QR para que mis compañeros y rivales se unan rápido.
- US-06 — Como jugador, quiero escanear el QR de un partido para unirme sin escribir nombres.
- US-07 — Como jugador, quiero añadir a un compañero que no tiene la app (invitado) para poder registrar el partido igual.
- US-08 — Como jugador, quiero registrar el marcador set por set para que el rating considere la diferencia de puntos.
- US-09 — Como jugador, quiero confirmar o disputar un resultado en 24 h para evitar que se registren partidos falsos.
- US-10 — Como jugador, quiero ver cómo cambió mi rating después de cada partido y por qué.
- US-11 — Como jugador, quiero ver mi confidence para saber qué tan asentado está mi rating.

**Rankings / Estadísticas**
- US-12 — Como jugador, quiero ver mi posición en el ranking de mi club/ciudad/país para compararme.
- US-13 — Como jugador, quiero ver mi historial de victorias/derrotas y mi evolución para seguir mi progreso.

**Pozos**
- US-14 — Como administrador, quiero crear un pozo con parejas fijas o rotación para organizar la jornada del club.
- US-15 — Como administrador, quiero que la app arme emparejamientos equilibrados por rating para que los partidos sean parejos.
- US-16 — Como jugador, quiero ver la tabla del pozo en tiempo real para saber cómo voy.
- US-17 — Como administrador, quiero cerrar el pozo y que los resultados actualicen el rating de todos.

**Torneos**
- US-18 — Como administrador, quiero crear un torneo con categorías por nivel/género para segmentar la competencia.
- US-19 — Como jugador, quiero inscribirme en una categoría para la que califico por mi rating.
- US-20 — Como administrador, quiero registrar resultados y que el bracket avance automáticamente.

**Notificaciones / Moderación**
- US-21 — Como jugador, quiero recibir un push cuando tengo una confirmación pendiente para no dejar partidos sin validar.
- US-22 — Como administrador, quiero recibir y resolver reportes/disputas para mantener la integridad del ranking.

---

## 6. User Flows

Notación: `→` paso siguiente; `[?]` decisión; `(sys)` acción del sistema.

### 6.1 Registro
```
Abrir app → Pantalla bienvenida → [? método]
  ├─ Email → ingresar email+password → (sys) Supabase crea user → verificar email → onboarding perfil
  ├─ Google → OAuth Google → (sys) crea/asocia user → onboarding perfil
  └─ Apple → OAuth Apple → (sys) crea/asocia user → onboarding perfil
Onboarding perfil → nombre, ciudad, club, mano, lado, nivel estimado → (sys) crea player vinculado a user
  → [? existe guest player con match difuso por nombre/teléfono] → sugerir reclamar perfil → US-03
  → Home
```

### 6.2 Login
```
Abrir app → [? sesión válida en almacenamiento seguro] 
  ├─ Sí → (sys) refresh token Supabase → Home
  └─ No → elegir método → autenticar → (sys) emite JWT → Home
```

### 6.3 Crear partido + QR
```
Home → "Nuevo partido" → elegir tipo (amistoso/competitivo)
  → definir formato (2v2) → (sys) crea match en estado DRAFT, genera token QR firmado (TTL 2 h)
  → mostrar QR + código corto
  → otros jugadores escanean (6.4) o se añaden manualmente / como invitados
  → cuando hay 4 jugadores → estado READY
```

### 6.4 Unirse mediante QR
```
Home → "Escanear QR" → cámara lee token → (sys) valida firma + TTL + cupo
  ├─ válido y hay cupo → unir jugador al equipo elegido → notificar al creador
  └─ inválido/expirado/lleno → mostrar error
```

### 6.5 Registrar resultado
```
Match READY → cualquier jugador o admin abre "Registrar resultado"
  → ingresar sets (ej. 6-3, 4-6, 7-5) → (sys) valida marcador coherente (reglas §7)
  → (sys) match pasa a PENDING_CONFIRMATION, abre ventana 24 h
  → notifica a todos los jugadores (push + in-app)
```

### 6.6 Confirmar / disputar resultado
```
PENDING_CONFIRMATION → jugador recibe push → abre partido
  ├─ Confirmar → (sys) suma confirmación
  │     └─ [? confirmaciones ≥ mayoría de jugadores reales] → CONFIRMED → encolar cálculo de rating
  ├─ Disputar → (sys) marca DISPUTED → notifica admin → resolución manual
  └─ Admin "Aprobar" → CONFIRMED directo (override)
[? pasan 24 h sin mayoría ni aprobación admin] → (sys) match DISCARDED → no afecta rating
```

### 6.7 Buscar jugador (lectura, MVP)
```
Tab Rankings/Buscar → filtros (ciudad, club, rango de rating, género)
  → (sys) consulta paginada sobre vista de ranking → lista → perfil público
(Matchmaking accionable → V1)
```

### 6.8 Crear pozo
```
Admin → "Nuevo pozo" → nombre, club, fecha, n.º canchas, modo (parejas fijas | rotación), 
        sistema de puntos (partidos), criterio de balance (por rating)
  → añadir participantes (jugadores reales + invitados)
  → (sys) genera Ronda 1: emparejamientos balanceados por rating (§7 Pozos)
  → jugar → registrar resultado por partido → (sys) actualiza tabla en vivo (Realtime)
  → (sys) genera siguiente ronda según resultados
  → Admin "Cerrar pozo" → (sys) marca partidos como CONFIRMED → encola rating
```

### 6.9 Crear torneo
```
Admin → "Nuevo torneo" → nombre, fechas, formato (eliminación simple | round-robin)
  → definir categorías (nivel: rango de rating; género)
  → abrir inscripciones → jugadores se inscriben en categoría válida
  → (sys) cierra inscripción → seed por rating → genera bracket / fixture round-robin
  → registrar resultados → (sys) avanza bracket / actualiza tabla
  → finalizar → clasificación final → encola rating
```

### 6.10 Crear americano *(V1 — documentado por completitud)*
```
Admin → "Nuevo americano" → n.º jugadores, n.º canchas, rondas
  → (sys) algoritmo de rotación individual (cada ronda nuevos compañeros/rivales)
  → ranking individual en vivo por puntos acumulados
```

---

## 7. Functional Requirements

Para cada módulo: **objetivo · comportamiento · validaciones · reglas de negocio · estados.**

### 7.1 Identidad y perfil
- **Objetivo:** identidad única por persona, con merge de invitados.
- **Comportamiento:** 1 `user` (Supabase Auth) ↔ 1 `player`. Un `player` puede existir sin `user` (invitado).
- **Validaciones:** email único; nombre 2–60 chars; foto ≤ 5 MB (jpg/png/webp); edad ≥ 12.
- **Reglas:** al reclamar un invitado, se hace **merge** de historial y se recalcula el rating del player resultante; el invitado origen queda `MERGED` (soft, apunta al player final).
- **Estados player:** `GUEST` · `ACTIVE` · `MERGED` · `DELETED`.

### 7.2 Partidos
- **Objetivo:** registrar partidos verificables que alimentan el rating.
- **Comportamiento:** un partido tiene 2 equipos, 1–2 jugadores por equipo, 1+ sets.
- **Validaciones de marcador (pádel estándar):**
  - Set se gana con 6 games con diferencia ≥ 2; con 5-5 se juega a 7 (7-5) o tie-break a 6-6 (7-6).
  - Partido al mejor de 3 sets por defecto; configurable (1 set, pro-set) por el creador/organizador.
  - El sistema rechaza marcadores imposibles (ej. 6-4, 6-4, 6-4 no procede; un 3-set ganado debe ser 2-1 en sets).
- **Reglas:**
  - Solo partidos `CONFIRMED` afectan el rating.
  - Partidos de **pozo/torneo** heredan confirmación del organizador (no requieren confirmación individual de los 4).
- **Estados:** `DRAFT` → `READY` → `PENDING_CONFIRMATION` → (`CONFIRMED` | `DISPUTED` → `CONFIRMED`/`DISCARDED` | `DISCARDED`).

### 7.3 Validación QR
- **Objetivo:** unir jugadores y atribuir el partido sin entrada manual de nombres.
- **Comportamiento:** el backend (NestJS) genera un **token firmado (JWT corto)** con `match_id`, `exp` (TTL 2 h), `nonce`. El QR codifica ese token + un código corto alfanumérico de respaldo.
- **Validaciones:** firma válida, no expirado, partido en `DRAFT`/`READY`, cupo disponible, jugador no duplicado.
- **Reglas anti-abuso:** un token QR solo sirve para *ese* partido; un dispositivo no puede unirse dos veces; rate limit de escaneos por usuario (§13/§16).
- **Estados token:** `ACTIVE` · `EXPIRED` · `CONSUMED`.

### 7.4 Confirmación de resultados
- **Objetivo:** garantizar veracidad antes de tocar el rating.
- **Comportamiento:** tras registrar marcador → `PENDING_CONFIRMATION`, ventana **24 h**.
- **Reglas:** se requiere confirmación de la **mayoría de jugadores reales** (no invitados; los invitados no votan) **o** aprobación de un **administrador**. Sin mayoría ni aprobación en 24 h → `DISCARDED`. Cualquier jugador puede **disputar** → `DISPUTED` (bloquea hasta resolución admin).
- **Mayoría:** `floor(jugadores_reales / 2) + 1`. Si solo hay 1 jugador real (caso degenerado con 3 invitados), requiere admin.
- **Estados:** ver 7.2.

### 7.5 Rating y Confidence
- **Objetivo:** medir nivel real con incertidumbre explícita. Detalle algorítmico en §12.
- **Comportamiento:** cálculo en NestJS al confirmarse un partido; escribe `rating_current` + `rating_history`.
- **Validaciones:** no recalcular partidos ya procesados (idempotencia por `match_id`); el merge de invitados dispara recálculo del historial del player.
- **Reglas:** período provisional (RD alto) primeros 5 partidos; la confidence decae con la inactividad; el rating no decae.
- **Estados rating:** `PROVISIONAL` (confidence < umbral) · `ESTABLISHED`.

### 7.6 Rankings
- **Objetivo:** listar jugadores ordenados por rating con filtros.
- **Comportamiento:** **vista materializada** refrescada por job (cada N min) para no recalcular en cada request a escala.
- **Validaciones:** solo jugadores `ESTABLISHED` aparecen en rankings públicos por defecto (los provisionales se marcan aparte) para evitar ruido.
- **Reglas:** filtros global/país/ciudad/club/género; edad → V1.
- **Estados:** N/A (lectura).

### 7.7 Pozos
- **Objetivo:** correr una jornada de juego organizado con tabla en vivo.
- **Comportamiento:** modos **parejas fijas** o **rotación** de individuales; n.º de canchas configurable.
- **Reglas de emparejamiento (balance por rating):**
  - *Parejas fijas:* las parejas se enfrentan buscando minimizar la diferencia de rating combinado entre equipos por cancha.
  - *Rotación:* cada ronda se forman parejas/cruces nuevos intentando equilibrar el rating combinado y evitar repetir compañero.
- **Clasificación:** por **partidos ganados**; **desempate por diferencia de games** (a favor − en contra); empates en partidos se mantienen como empate en la tabla.
- **Reglas:** al cerrar, cada partido del pozo se materializa como `match CONFIRMED` (origen `POZO`) y alimenta el rating.
- **Estados pozo:** `DRAFT` → `OPEN` → `IN_PROGRESS` → `CLOSED` · (`CANCELLED`).

### 7.8 Torneos
- **Objetivo:** competencia formal por categorías con bracket/fixture.
- **Comportamiento:** **eliminación simple** (bracket con seeds por rating) o **round-robin** (todos contra todos por grupo).
- **Validaciones:** un jugador solo se inscribe en categorías cuyo rango de rating/género cumple; bracket requiere potencia de 2 o byes automáticos.
- **Reglas:** resultados avanzan el bracket automáticamente; round-robin clasifica por partidos ganados → games. Al finalizar, partidos → rating (origen `TORNEO`).
- **Estados torneo:** `DRAFT` → `REGISTRATION_OPEN` → `REGISTRATION_CLOSED` → `IN_PROGRESS` → `FINISHED` · (`CANCELLED`).

### 7.9 Notificaciones
- **Objetivo:** llevar al usuario a acciones pendientes y avisarle de cambios.
- **Comportamiento:** push (FCM) + registro in-app. Detalle en §14.
- **Reglas:** dedupe por `event_id`; respeta preferencias de notificación del usuario.

### 7.10 Moderación / Disputas
- **Objetivo:** resolver resultados disputados y reportes.
- **Comportamiento:** cola de disputas/reportes visible para `administrador`; acción de aprobar/descartar/editar marcador (con log de auditoría).
- **Estados disputa:** `OPEN` → `RESOLVED` (`UPHELD`/`OVERTURNED`).

---

## 8. Non-Functional Requirements

- **Rendimiento:** p95 de endpoints de lectura < 300 ms; escritura de resultado < 500 ms; cálculo de rating asíncrono < 2 s tras confirmación. App: arranque en frío < 3 s; pantallas principales < 1 s con datos cacheados.
- **Disponibilidad:** objetivo 99.5 % mensual para el MVP. Sin SLA estricto (equipo pequeño), pero con health checks y reinicio automático.
- **Escalabilidad:** arquitectura sin estado en NestJS (escala horizontal); cálculos pesados en cola/jobs; rankings en vistas materializadas. Diseño para 100k usuarios, infra dimensionada para ~10k.
- **Seguridad:** TLS en todo; JWT con expiración corta + refresh; RLS en Postgres; rate limiting; validación de entrada estricta. Ver §16.
- **Observabilidad:** logs estructurados (JSON) con correlación por `request_id`; métricas (latencia, throughput, errores, profundidad de colas); trazas básicas. Analítica de producto en PostHog.
- **Monitoreo:** alertas por tasa de error 5xx, latencia p95, fallos de jobs de rating, profundidad de cola, caída de DB.
- **Recuperación ante fallos:** backups automáticos diarios de Postgres (Supabase) + point-in-time recovery según plan; jobs de rating idempotentes y reintentables; cola con dead-letter para resultados no procesados.
- **Privacidad / cumplimiento:** Ley 8968 (CR): consentimiento, acceso, rectificación y **borrado** de datos; minimización (no pedir cédula); foto y ubicación opcionales/aproximadas.
- **Accesibilidad / i18n:** textos externalizados (ES base), preparado para más idiomas; contraste y tamaños de toque conforme a guías móviles.

---

## 9. System Architecture

### 9.1 Visión de capas
```
┌──────────────────────────────────────────────────────────┐
│                     App Flutter (iOS/Android)             │
│  UI (widgets) · State (Riverpod/BLoC) · Repos · API client│
└───────────────┬───────────────────────┬──────────────────┘
                │ HTTPS REST/JSON        │ Realtime (WebSocket)
                ▼                        ▼
        ┌───────────────┐        ┌──────────────────┐
        │  NestJS API   │        │ Supabase Realtime │
        │ (lógica neg.) │        │ (tablas en vivo)  │
        └──────┬────────┘        └─────────┬─────────┘
               │ SQL / RPC                 │ subscribe
               ▼                           ▼
        ┌──────────────────────────────────────────────┐
        │            Supabase / PostgreSQL              │
        │  Auth · Storage(fotos) · Postgres(RLS) · cron │
        └──────────────────────────────────────────────┘
               ▲
               │ jobs/colas
        ┌──────┴────────┐      ┌──────────────┐     ┌──────────┐
        │ Worker rating │      │  FCM (push)  │     │ PostHog  │
        │ (cola BullMQ) │      └──────────────┘     └──────────┘
        └───────────────┘
```

### 9.2 Reparto de responsabilidades
- **Supabase:** identidad (Auth: email/Google/Apple), almacenamiento de fotos, Postgres con RLS para lecturas directas seguras desde la app (perfiles, rankings públicos, tablas de pozo en vivo vía Realtime), backups, cron simple.
- **NestJS:** **toda mutación sensible** — creación/confirmación de partidos, generación y validación de QR, cálculo de rating, anti-fraude, generación de pozos/brackets, merge de invitados, moderación. La app **no** escribe rating ni confirma resultados directamente en Postgres; pasa por NestJS.
- **Flutter:** lectura directa de datos públicos vía Supabase (con RLS) para velocidad; escrituras y operaciones de negocio vía NestJS. Realtime para tablas en vivo.

> **Decisión clave de seguridad:** las tablas `rating_current`, `rating_history`, `match_*` son **solo-lectura** vía RLS para el cliente; su escritura está restringida al `service_role` que usa NestJS.

### 9.3 Arquitectura Flutter (capas)
```
presentation/  (pantallas, widgets, navegación GoRouter)
state/         (Riverpod providers / BLoC por feature)
domain/        (entidades, casos de uso)
data/          (repositorios, datasources: ApiClient NestJS + SupabaseClient)
core/          (auth, almacenamiento seguro de tokens, i18n, theming, errores)
```
- **Estado:** Riverpod (recomendado para equipo pequeño) o BLoC.
- **Navegación:** GoRouter.
- **Red:** Dio + interceptores (auth, reintentos, manejo 401→refresh).
- **Cache local:** Hive/Isar para perfil y datos de solo lectura (no offline-first; solo caché de UX).

### 9.4 Arquitectura NestJS (módulos)
```
AuthModule        (verificación de JWT Supabase, guards, roles)
UsersModule       (perfil, merge de invitados)
MatchesModule     (partidos, QR, confirmación, estados)
RatingModule      (motor Glicko-2 adaptado, cola de cálculo)
RankingsModule    (refresco de vistas materializadas)
PozosModule       (generación de rondas, balance, cierre)
TournamentsModule (brackets, round-robin, avance)
NotificationsModule (FCM, in-app, plantillas, dedupe)
ModerationModule  (disputas, reportes, auditoría)
AntiFraudModule   (detección de anomalías, validaciones)
AnalyticsModule   (emisión de eventos a PostHog)
CommonModule      (config, logging, rate limiting, validación)
```
- **Colas:** BullMQ sobre Redis para cálculo de rating y notificaciones.
- **Comunicación:** REST/JSON con la app; service-role key hacia Postgres; SDK admin de FCM.

---

## 10. Database Design (PostgreSQL)

Modelo relacional principal. Tipos abreviados; PK = clave primaria; FK = foránea; `uuid` por defecto `gen_random_uuid()`.

### 10.1 Identidad
```sql
-- users: gestionado por Supabase Auth (auth.users). Espejo de dominio:
profiles (
  id            uuid PK REFERENCES auth.users(id),
  role          text NOT NULL DEFAULT 'jugador' CHECK (role IN ('jugador','administrador')),
  player_id     uuid UNIQUE REFERENCES players(id),
  created_at    timestamptz NOT NULL DEFAULT now()
)

players (
  id             uuid PK,
  user_id        uuid NULL UNIQUE REFERENCES auth.users(id),   -- NULL => invitado
  status         text NOT NULL DEFAULT 'ACTIVE'
                   CHECK (status IN ('GUEST','ACTIVE','MERGED','DELETED')),
  merged_into    uuid NULL REFERENCES players(id),             -- si MERGED
  full_name      text NOT NULL,
  photo_url      text,
  city           text,
  club_id        uuid REFERENCES clubs(id),
  dominant_hand  text CHECK (dominant_hand IN ('R','L')),
  fav_side       text CHECK (fav_side IN ('DRIVE','REVES','BOTH')),
  gender         text CHECK (gender IN ('M','F','OTHER','NA')),
  birthdate      date NULL,                                    -- requerido para ranking por edad (V1)
  est_level      numeric(3,1),                                 -- nivel autodeclarado inicial
  created_by     uuid REFERENCES players(id),                  -- quién creó el invitado
  created_at     timestamptz NOT NULL DEFAULT now()
)

clubs (
  id        uuid PK,
  name      text NOT NULL,
  city      text,
  claimed_by uuid NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
)
```

### 10.2 Partidos
```sql
matches (
  id           uuid PK,
  type         text NOT NULL CHECK (type IN ('FRIENDLY','COMPETITIVE','POZO','TOURNAMENT')),
  source_id    uuid NULL,                  -- pozo_id o tournament_id según type
  status       text NOT NULL DEFAULT 'DRAFT'
                 CHECK (status IN ('DRAFT','READY','PENDING_CONFIRMATION',
                                   'CONFIRMED','DISPUTED','DISCARDED')),
  best_of      int NOT NULL DEFAULT 3 CHECK (best_of IN (1,3)),
  created_by   uuid NOT NULL REFERENCES players(id),
  played_at    timestamptz,
  confirm_deadline timestamptz,            -- created + 24h
  rating_applied boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
)

match_teams (
  id        uuid PK,
  match_id  uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  side      int NOT NULL CHECK (side IN (1,2)),
  UNIQUE (match_id, side)
)

match_players (
  match_id  uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  team_id   uuid NOT NULL REFERENCES match_teams(id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES players(id),
  PRIMARY KEY (match_id, player_id)
)

match_sets (
  id        uuid PK,
  match_id  uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  set_no    int NOT NULL,
  games_1   int NOT NULL CHECK (games_1 >= 0),
  games_2   int NOT NULL CHECK (games_2 >= 0),
  tiebreak_1 int, tiebreak_2 int,
  UNIQUE (match_id, set_no)
)

match_results (
  match_id     uuid PK REFERENCES matches(id) ON DELETE CASCADE,
  winner_side  int NOT NULL CHECK (winner_side IN (1,2)),
  games_diff   int NOT NULL,               -- diferencia total de games (para desempates/MOV)
  reported_by  uuid NOT NULL REFERENCES players(id),
  reported_at  timestamptz NOT NULL DEFAULT now()
)

match_confirmations (
  match_id   uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  player_id  uuid NOT NULL REFERENCES players(id),
  decision   text NOT NULL CHECK (decision IN ('CONFIRM','DISPUTE')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, player_id)
)

qr_tokens (
  id        uuid PK,
  match_id  uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  short_code text UNIQUE,
  status    text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','EXPIRED','CONSUMED')),
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)
```

### 10.3 Rating
```sql
rating_current (
  player_id   uuid PK REFERENCES players(id) ON DELETE CASCADE,
  mu          numeric(8,4) NOT NULL,       -- habilidad latente (Glicko-2)
  rd          numeric(8,4) NOT NULL,       -- desviación (=> confidence)
  sigma       numeric(8,4) NOT NULL,       -- volatilidad
  rating_display numeric(3,1) NOT NULL,    -- escala 1.0–7.0
  confidence  int NOT NULL,                -- 0–100
  state       text NOT NULL DEFAULT 'PROVISIONAL'
                CHECK (state IN ('PROVISIONAL','ESTABLISHED')),
  matches_count int NOT NULL DEFAULT 0,
  last_match_at timestamptz,
  updated_at  timestamptz NOT NULL DEFAULT now()
)

rating_history (
  id          uuid PK,
  player_id   uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  match_id    uuid NOT NULL REFERENCES matches(id),
  mu_before numeric(8,4), mu_after numeric(8,4),
  rd_before numeric(8,4), rd_after numeric(8,4),
  rating_before numeric(3,1), rating_after numeric(3,1),
  delta       numeric(3,1),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (player_id, match_id)             -- idempotencia
)
```

### 10.4 Pozos
```sql
pozos (
  id         uuid PK,
  name       text NOT NULL,
  club_id    uuid REFERENCES clubs(id),
  owner_id   uuid NOT NULL REFERENCES auth.users(id),
  mode       text NOT NULL CHECK (mode IN ('FIXED_PAIRS','ROTATION')),
  courts     int NOT NULL CHECK (courts > 0),
  status     text NOT NULL DEFAULT 'DRAFT'
               CHECK (status IN ('DRAFT','OPEN','IN_PROGRESS','CLOSED','CANCELLED')),
  scheduled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
)
pozo_participants ( pozo_id uuid REFERENCES pozos(id) ON DELETE CASCADE,
                    player_id uuid REFERENCES players(id),
                    PRIMARY KEY (pozo_id, player_id) )
pozo_rounds ( id uuid PK, pozo_id uuid REFERENCES pozos(id) ON DELETE CASCADE,
              round_no int NOT NULL, UNIQUE (pozo_id, round_no) )
pozo_matches ( id uuid PK, round_id uuid REFERENCES pozo_rounds(id) ON DELETE CASCADE,
               court int, match_id uuid REFERENCES matches(id) )
pozo_standings ( pozo_id uuid REFERENCES pozos(id) ON DELETE CASCADE,
                 player_id uuid REFERENCES players(id),
                 wins int DEFAULT 0, draws int DEFAULT 0, losses int DEFAULT 0,
                 games_for int DEFAULT 0, games_against int DEFAULT 0,
                 PRIMARY KEY (pozo_id, player_id) )
```

### 10.5 Torneos
```sql
tournaments ( id uuid PK, name text NOT NULL, owner_id uuid REFERENCES auth.users(id),
              format text CHECK (format IN ('SINGLE_ELIM','ROUND_ROBIN')),
              status text DEFAULT 'DRAFT'
                CHECK (status IN ('DRAFT','REGISTRATION_OPEN','REGISTRATION_CLOSED',
                                  'IN_PROGRESS','FINISHED','CANCELLED')),
              start_date date, end_date date )
tournament_categories ( id uuid PK, tournament_id uuid REFERENCES tournaments(id) ON DELETE CASCADE,
                        name text, gender text CHECK (gender IN ('M','F','MIXED','OPEN')),
                        min_rating numeric(3,1), max_rating numeric(3,1) )
tournament_registrations ( id uuid PK, category_id uuid REFERENCES tournament_categories(id) ON DELETE CASCADE,
                           player1_id uuid REFERENCES players(id),
                           player2_id uuid REFERENCES players(id),
                           seed int, UNIQUE (category_id, player1_id, player2_id) )
tournament_matches ( id uuid PK, category_id uuid REFERENCES tournament_categories(id) ON DELETE CASCADE,
                     round int, bracket_pos int,
                     reg_a uuid REFERENCES tournament_registrations(id),
                     reg_b uuid REFERENCES tournament_registrations(id),
                     match_id uuid REFERENCES matches(id),
                     next_match_id uuid REFERENCES tournament_matches(id) )
```

### 10.6 Transversales
```sql
notifications ( id uuid PK, user_id uuid REFERENCES auth.users(id),
                type text, payload jsonb, read_at timestamptz,
                event_id text UNIQUE, created_at timestamptz DEFAULT now() )
devices ( id uuid PK, user_id uuid REFERENCES auth.users(id),
          fcm_token text, platform text CHECK (platform IN ('ios','android')),
          updated_at timestamptz DEFAULT now(), UNIQUE (fcm_token) )
reports ( id uuid PK, reporter_id uuid REFERENCES players(id),
          target_type text, target_id uuid, reason text,
          status text DEFAULT 'OPEN', created_at timestamptz DEFAULT now() )
audit_log ( id uuid PK, actor_id uuid, action text, entity text, entity_id uuid,
            before jsonb, after jsonb, created_at timestamptz DEFAULT now() )
```

### 10.7 Índices clave
- `players (user_id)`, `players (status)`, `players (club_id)`, GIN trigram en `players(full_name)` para sugerir merge.
- `matches (status, confirm_deadline)` para el job que descarta a las 24 h.
- `matches (type, source_id)`; `match_players (player_id)`.
- `rating_current (rating_display DESC)`, `(state)`, `(club_id via join)` — base del ranking.
- `rating_history (player_id, created_at)`.
- `qr_tokens (short_code)`, `(status, expires_at)`.

### 10.8 Vista materializada de ranking
```sql
CREATE MATERIALIZED VIEW mv_rankings AS
SELECT p.id AS player_id, p.full_name, p.city, p.club_id, p.gender,
       rc.rating_display, rc.confidence, rc.state, rc.matches_count
FROM players p JOIN rating_current rc ON rc.player_id = p.id
WHERE p.status = 'ACTIVE' AND rc.state = 'ESTABLISHED';
-- refresh CONCURRENTLY por job cada 5–15 min
```

### 10.9 Notas RLS
- `profiles`, `players`, `mv_rankings`: SELECT público (datos no sensibles); UPDATE solo el dueño sobre su `player`.
- `matches`, `match_*`, `rating_*`, `pozo_*`, `tournament_*`: SELECT según pertenencia; **INSERT/UPDATE solo `service_role`** (NestJS).
- `audit_log`: solo `service_role`.

---

## 11. API Design (NestJS · REST/JSON)

Convenciones: base `/api/v1`; auth con `Authorization: Bearer <supabase_jwt>`; errores con `{ code, message, details }`; paginación `?page&limit` con `{ data, page, total }`.

### 11.1 Auth / Perfil
| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| GET | `/me` | jugador | Perfil + rating propio |
| PATCH | `/me` | jugador | Editar perfil |
| POST | `/me/photo` | jugador | Subir foto (devuelve URL Storage) |
| DELETE | `/me` | jugador | Borrado de cuenta (Ley 8968) |
| GET | `/players/:id` | jugador | Perfil público |
| POST | `/players/guest` | jugador | Crear jugador invitado |
| GET | `/players/guest/suggestions` | jugador | Invitados que podrían ser "yo" (trigram) |
| POST | `/players/:guestId/claim` | jugador | Reclamar/merge invitado → recálculo rating |

Ejemplo `PATCH /me` request/response:
```json
// req
{ "city": "San José", "club_id": "…", "dominant_hand": "R", "fav_side": "REVES", "est_level": 3.5 }
// res 200
{ "id": "…", "full_name": "…", "rating": { "rating": 3.6, "confidence": 42, "state": "PROVISIONAL" } }
```

### 11.2 Partidos / QR
| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| POST | `/matches` | jugador | Crear partido (DRAFT) |
| POST | `/matches/:id/qr` | jugador (creador) | Generar QR firmado |
| POST | `/matches/join` | jugador | Unirse por token/short_code |
| POST | `/matches/:id/result` | jugador/admin | Registrar marcador (→ PENDING) |
| POST | `/matches/:id/confirm` | jugador | Confirmar |
| POST | `/matches/:id/dispute` | jugador | Disputar |
| POST | `/matches/:id/approve` | admin | Forzar confirmación |
| GET | `/matches/:id` | jugador | Detalle + estado |
| GET | `/me/matches` | jugador | Historial paginado |

Ejemplo `POST /matches/:id/result`:
```json
// req
{ "sets": [ {"games_1":6,"games_2":3}, {"games_1":4,"games_2":6}, {"games_1":7,"games_2":5} ] }
// res 200
{ "status": "PENDING_CONFIRMATION", "winner_side": 1, "confirm_deadline": "2026-06-16T20:00:00Z",
  "required_confirmations": 3 }
```

### 11.3 Rating / Rankings
| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| GET | `/players/:id/rating` | jugador | Rating + confidence + estado |
| GET | `/players/:id/rating/history` | jugador | Evolución |
| GET | `/rankings` | jugador | `?scope=global|country|city|club|gender&value=…` |

### 11.4 Pozos
| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| POST | `/pozos` | admin | Crear pozo |
| POST | `/pozos/:id/participants` | admin | Añadir participantes |
| POST | `/pozos/:id/start` | admin | Generar Ronda 1 (balance por rating) |
| POST | `/pozos/:id/rounds/:n/results` | admin | Registrar resultados de ronda |
| POST | `/pozos/:id/next-round` | admin | Generar siguiente ronda |
| GET | `/pozos/:id/standings` | jugador | Tabla (también vía Realtime) |
| POST | `/pozos/:id/close` | admin | Cerrar → aplica rating |

### 11.5 Torneos
| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| POST | `/tournaments` | admin | Crear |
| POST | `/tournaments/:id/categories` | admin | Definir categorías |
| POST | `/tournaments/:id/register` | jugador | Inscribir pareja en categoría |
| POST | `/tournaments/:id/generate` | admin | Bracket/fixture (seed por rating) |
| POST | `/tournament-matches/:id/result` | admin | Registrar y avanzar |
| GET | `/tournaments/:id` | jugador | Estado + brackets |

### 11.6 Notificaciones / Moderación
| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| POST | `/devices` | jugador | Registrar token FCM |
| GET | `/me/notifications` | jugador | In-app, paginado |
| POST | `/notifications/:id/read` | jugador | Marcar leída |
| GET | `/admin/disputes` | admin | Cola de disputas |
| POST | `/admin/disputes/:id/resolve` | admin | Resolver |
| POST | `/admin/users/:id/role` | admin | Asignar rol administrador |

---

## 12. Rating System Design

### 12.1 Elección y fundamento
Algoritmo **propio** sobre base **Glicko-2 adaptado a dobles con margen de victoria (MOV)**. Razones: Glicko-2 trae nativamente la **desviación del rating (RD)** y la **volatilidad (σ)**, lo que da gratis el **Confidence Score** y el período provisional; es más estable que Elo simple con pocos datos y maneja bien la incertidumbre, requisito central en una red nueva.

**Mapeo de escala visible:** la habilidad latente `μ` (Glicko-2, escala interna ~1500±) se transforma linealmente a una **escala 1.0–7.0** tipo DUPR:
```
rating_display = clamp(1.0, 7.0, 1.0 + (μ - μ_min) * (6.0) / (μ_max - μ_min))
```
con `μ_min`/`μ_max` calibrados sobre la población (recalibración periódica).

**Confidence (0–100):** función inversa de RD:
```
confidence = round( 100 * (1 - clamp(0,1, (RD - RD_min) / (RD_max - RD_min))) )
state = 'ESTABLISHED' si confidence ≥ 50 (umbral configurable), si no 'PROVISIONAL'
```

### 12.2 Inputs / Outputs
- **Inputs por partido:** equipos (1–2 jugadores), `winner_side`, sets (para MOV), `μ/RD/σ` actuales de cada jugador.
- **Outputs:** nuevos `μ/RD/σ` por jugador + `rating_display` + `confidence` + fila en `rating_history`.

### 12.3 Adaptación a dobles
- Rating de equipo = **promedio** de los `μ` de sus jugadores; RD de equipo = combinación (raíz de la media de varianzas).
- Resultado esperado del equipo A vs B con función logística estándar de Glicko-2 sobre la diferencia de ratings de equipo (ponderada por `g(RD)`).
- El **delta** del equipo se **distribuye a cada jugador** proporcionalmente a su `RD` (quien tiene más incertidumbre cambia más), preservando consistencia con Glicko-2.

### 12.4 Margen de victoria (MOV)
El "score observado" deja de ser binario 1/0 y se modula por el marcador, **acotado** para evitar que palizas exploten el rating:
```
mov = clamp(0.5, 1.0, 0.5 + k * (games_diff / total_games))   // ganador
// el perdedor recibe (1 - mov)
```
con `k` calibrado (ej. 0.5) y `total_games` del partido. Así 6-2,6-1 pesa más que 7-6,7-5, pero con techo.

### 12.5 Período provisional y decay
- **Provisional:** jugadores nuevos arrancan con `RD` alto (≈ valor inicial Glicko-2), por lo que sus primeros ~5 partidos mueven mucho el rating y `state = PROVISIONAL`.
- **Decay de confidence por inactividad:** un job aumenta `RD` con el tiempo sin jugar (fórmula de Glicko-2 de incremento de RD por período inactivo). **`μ` (rating) no cambia** por inactividad, solo baja la confidence — exactamente lo pedido.

### 12.6 Procesamiento
- **MVP:** cálculo **incremental por partido confirmado** (cada partido como mini-período), encolado en BullMQ tras `CONFIRMED`. Idempotente por `(player_id, match_id)`.
- **Escala (V2+):** opción de **rating periods** en lote nocturno para reducir carga si el volumen crece.
- **Pozos/torneos:** al cerrar, sus partidos se procesan en orden cronológico.

### 12.7 Versiones
- **MVP:** Glicko-2 + dobles (promedio) + MOV acotado + provisional + decay de confidence.
- **V2:** distribución de delta por RD afinada; rating de **singles** separado; calibración automática de escala por población.
- **V3:** ponderación por **calidad/confidence del oponente**, anti-inflación regional (normalización entre clubes/zonas), e incorporación opcional de "minutos jugados"/recencia con mayor peso a partidos recientes.

---

## 13. Fraud Prevention System

El valor del producto = confianza en el rating, así que el anti-fraude es de primera clase.

- **Detección de anomalías (job + reglas):**
  - Saltos de rating fuera de banda (delta > N desviaciones) → marca para revisión.
  - Mismos 4 jugadores repitiendo muchos partidos en poco tiempo con marcadores extremos → patrón de "farmeo".
  - Resultados que solo benefician a una cuenta nueva contra invitados que nunca se registran.
- **Validación de partidos:**
  - Marcadores imposibles bloqueados a nivel de validación (§7.2).
  - Confirmación por mayoría/admin obligatoria; los invitados no cuentan para mayoría.
  - Límite de partidos confirmables por jugador/día sin pasar por pozo/torneo.
- **Abuso de cuentas:**
  - Detección de cuentas duplicadas (mismo dispositivo, mismos patrones) → fusión/sanción por admin.
  - Verificación de email/OAuth obligatoria; teléfono (V1) como señal adicional.
  - Rate limiting de creación de invitados por usuario.
- **Abuso de QR:**
  - Token firmado con TTL corto, `nonce`, un solo `match`; estado `CONSUMED`.
  - Un dispositivo/cuenta no se une dos veces; rate limit de escaneos.
- **Manipulación de resultados:**
  - Ventana de disputa de 24 h; disputa congela el rating hasta resolución.
  - `audit_log` de toda edición/aprobación admin.
  - "Trust weight": partidos de torneos/pozos administrados pesan más que amistosos sin verificación cruzada (parámetro de confianza por origen).

---

## 14. Notification Architecture

- **Canales:** Push (FCM, iOS+Android) + In-App (tabla `notifications`).
- **Flujo:** evento de dominio en NestJS → `NotificationsModule` arma payload desde plantilla → encola → envía FCM + inserta in-app. **Dedupe** por `event_id`.
- **Tokens:** la app registra/actualiza `fcm_token` en `/devices`; tokens inválidos se purgan al fallar el envío.
- **Preferencias:** el usuario puede silenciar categorías (se respeta antes de enviar).

**Eventos que generan notificación:**
| Evento | Destinatarios |
|---|---|
| Resultado registrado → confirmación pendiente | jugadores reales del partido |
| Resultado disputado | admin / jugadores |
| Partido descartado por 24 h | jugadores |
| Cambio de rating tras partido | jugador |
| Invitación a pozo/torneo | invitados |
| Nueva ronda de pozo / próximo partido | participantes |
| Tu perfil fue reclamado / sugerencia de merge | usuario |
| Resolución de disputa | involucrados |
| Recordatorio de evento próximo | participantes |

---

## 15. Analytics Design (PostHog)

Emisión desde NestJS (server-side, fiable) y eventos de UI desde Flutter (SDK PostHog). Identidad por `distinct_id = user_id`.

**Eventos núcleo:**
| Evento | Propiedades |
|---|---|
| `user_registered` | método (email/google/apple) |
| `user_logged_in` | método |
| `profile_completed` | campos llenos |
| `guest_player_created` | — |
| `guest_player_claimed` | matches_merged |
| `match_created` | type |
| `match_qr_generated` / `match_joined_qr` | — |
| `match_result_reported` | best_of |
| `match_confirmed` / `match_disputed` / `match_discarded` | tiempo_a_confirmar |
| `rating_updated` | delta, state |
| `ranking_viewed` | scope |
| `pozo_created` / `pozo_closed` | participantes, rondas |
| `tournament_created` / `tournament_finished` | formato, categorías |
| `notification_opened` | type |

**Embudos a vigilar:** registro→perfil completo→primer partido→primer partido confirmado→rating ESTABLISHED. Retención por cohortes de "primer partido confirmado".

---

## 16. Security Design

- **Autenticación:** Supabase Auth (Email + Google + Apple). NestJS **verifica el JWT** (JWKS de Supabase) en un guard; nunca confía en claims sin verificar. "Sign in with Apple" habilitado (requisito de App Store si hay login social).
- **Autorización:** guard de roles (`jugador`/`administrador`) + verificación de **propiedad del recurso** (owner del pozo/torneo, jugador del partido). RLS como segunda barrera en Postgres.
- **Protección de APIs:** validación estricta de entrada (class-validator/DTOs), allowlist de campos, sanitización; CORS restringido; tamaño de payload limitado.
- **Rate limiting:** por IP + por usuario (creación de partidos, escaneo QR, creación de invitados, login). Throttler de NestJS + límites en gateway.
- **Validación de datos:** marcadores coherentes, rangos numéricos, tipos enum; rechazo de mutaciones a tablas de rating desde el cliente (solo `service_role`).
- **Protección contra fraude:** ver §13.
- **Secretos:** en gestor de secretos del proveedor (no en repo); `service_role key` solo en backend.
- **Datos personales (Ley 8968):** cifrado en tránsito y en reposo (provee Supabase), borrado de cuenta efectivo, minimización (sin cédula), ubicación aproximada (ciudad), foto opcional.

---

## 17. Testing Strategy

- **Unit tests (alta cobertura en lógica crítica):** motor de rating (casos sintéticos con resultados esperados), validación de marcadores, generación de emparejamientos de pozo, avance de brackets, lógica de mayoría/confirmación. Objetivo ≥ 80 % en `RatingModule`, `MatchesModule`, `PozosModule`, `TournamentsModule`.
- **Integration tests:** endpoints NestJS contra una Postgres de prueba (Testcontainers): crear→unir por QR→registrar→confirmar→rating aplicado; cierre de pozo aplica rating; RLS efectiva.
- **E2E:** Flutter `integration_test` en los flujos críticos (registro, crear partido, escanear QR, confirmar, ver ranking) en dispositivos/emuladores iOS y Android.
- **QA manual:** matriz de dispositivos (gama baja Android, iPhone reciente y antiguo), pruebas de cámara/QR en condiciones reales de cancha, casos de invitados y merge, disputas.
- **Pruebas específicas de rating:** dataset de regresión que congela outputs esperados para detectar cambios no intencionales del algoritmo.
- **Carga (previo a escala):** k6/Artillery sobre lecturas de ranking y registro de resultados.

---

## 18. CI/CD Strategy

- **Ambientes:** `local` → `staging` (Supabase proyecto staging + NestJS staging) → `production`. DB separada por ambiente; migraciones versionadas (Prisma/Drizzle o SQL migrations).
- **Pipeline (GitHub Actions):**
  - PR: lint + unit + integration (Testcontainers) + build Flutter (analyze/test).
  - Merge a `main`: deploy backend a staging (contenedor en Fly.io/Render/Railway — opción barata), migraciones automáticas, smoke tests.
  - Tag release: build Flutter (Fastlane) → TestFlight + Google Play (internal track) → promoción manual a producción.
- **Backend hosting (barato pero bueno):** contenedor NestJS en Fly.io o Render; Redis gestionado pequeño para BullMQ; Supabase plan inicial. Escalado horizontal cuando haga falta.
- **Migraciones:** nunca destructivas en caliente; estrategia expand/contract.
- **Rollback:** imágenes versionadas; migraciones reversibles; feature flags para módulos pesados (pozos/torneos).
- **Observabilidad en CI/CD:** healthcheck `/health`; alertas a un canal del equipo.

---

## 19. Roadmap Técnico

Sprints de ~2 semanas; equipo 2–3 personas; sin deadline duro (calidad > velocidad). Cada sprint: *objetivos · funcionalidades · dependencias · entregables.*

### Sprint 0 — Fundaciones
- **Objetivos:** repos, ambientes, esqueletos.
- **Funcionalidades:** monorepo (o repos separados), proyecto Supabase, scaffold NestJS + Flutter, CI básico, esquema DB inicial + migraciones, `/health`.
- **Dependencias:** ninguna.
- **Entregables:** app que arranca, backend desplegado en staging, DB migrada, pipeline verde.

### Sprint 1 — Identidad y perfil
- **Objetivos:** registro/login y perfil.
- **Funcionalidades:** Auth (Email/Google/Apple), onboarding de perfil, foto a Storage, jugadores invitados + sugerencia de merge, borrado de cuenta.
- **Dependencias:** Sprint 0.
- **Entregables:** usuario puede registrarse, completar perfil y crear invitados.

### Sprint 2 — Partidos + QR
- **Objetivos:** crear y unirse a partidos.
- **Funcionalidades:** crear partido (DRAFT/READY), QR firmado, unirse por QR/código, captura de sets con validación de marcador.
- **Dependencias:** Sprint 1.
- **Entregables:** flujo de partido hasta `PENDING_CONFIRMATION`.

### Sprint 3 — Confirmación + Motor de Rating
- **Objetivos:** rating confiable.
- **Funcionalidades:** confirmación mayoría/admin + ventana 24 h + job de descarte; `RatingModule` (Glicko-2 + dobles + MOV) con cola BullMQ; `rating_current`/`rating_history`; recálculo en merge.
- **Dependencias:** Sprint 2; Redis.
- **Entregables:** un partido confirmado actualiza rating y confidence; tests de regresión del rating.

### Sprint 4 — Rankings + Perfil estadístico
- **Objetivos:** mostrar nivel y comparativas.
- **Funcionalidades:** vista materializada + job de refresco; endpoints de ranking (global/país/ciudad/club/género); historial y evolución en la app.
- **Dependencias:** Sprint 3.
- **Entregables:** rankings navegables y perfil con evolución.

### Sprint 5 — Notificaciones + Moderación
- **Objetivos:** cerrar el ciclo de confirmación y dar herramientas a admins.
- **Funcionalidades:** FCM + in-app + preferencias; panel admin (asignar rol, cola de disputas, aprobar/forzar resultados); `audit_log`; analítica PostHog núcleo.
- **Dependencias:** Sprints 3–4.
- **Entregables:** push de confirmaciones, resolución de disputas, eventos en PostHog.

### Sprint 6 — Pozos
- **Objetivos:** juego organizado básico.
- **Funcionalidades:** crear pozo (fijas/rotación), participantes (reales+invitados), generación balanceada por rating, tabla en vivo (Realtime), cierre que aplica rating.
- **Dependencias:** Sprints 2–3.
- **Entregables:** un club corre un pozo completo end-to-end.

### Sprint 7 — Torneos
- **Objetivos:** competencia formal.
- **Funcionalidades:** torneos (eliminación simple + round-robin), categorías por nivel/género, inscripción, seed/bracket/fixture, avance automático, rating al finalizar.
- **Dependencias:** Sprints 2–3.
- **Entregables:** un torneo por categorías de principio a fin.

### Sprint 8 — Hardening + Lanzamiento
- **Objetivos:** producción.
- **Funcionalidades:** anti-fraude (reglas + anomalías), rate limiting fino, pruebas de carga, accesibilidad/i18n, pulido de UX, observabilidad/alertas, builds de tienda (TestFlight/Play).
- **Dependencias:** todo lo anterior.
- **Entregables:** **v1.0 MVP en producción** (Android + iOS).

> **Post-MVP (V1):** teléfono como login, matchmaking, americanos, ranking por edad, estadísticas avanzadas, compatibilidad de parejas.

---

## 20. Riesgos Técnicos

| # | Riesgo | Tipo | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | **Algoritmo de rating mal calibrado** (inflado/deflactado o injusto con pocos datos) | Datos/Algoritmo | Pérdida de confianza en el producto | Período provisional + RD; dataset de regresión; calibración periódica de escala; "trust weight" por origen; capacidad de recalcular todo el historial |
| R2 | **Fraude / farmeo de rating** | Datos/Seguridad | Rankings sin valor | Anti-fraude §13; mayoría/admin; invitados no votan; auditoría; límites por día |
| R3 | **Bootstrapping de la red** (pocos jugadores con app) | Producto/Datos | Rating poco confiable al inicio | Jugadores invitados reclamables; pozos/torneos administrados como fuente densa de partidos verificados |
| R4 | **Cuello de botella en cálculo de rating** a volumen alto | Escalabilidad | Latencia/atrasos | Cola BullMQ + workers escalables; opción de rating periods en lote (V2); idempotencia |
| R5 | **Rankings costosos** si se calculan por request | Escalabilidad | Latencia | Vista materializada + refresco por job; índices dedicados |
| R6 | **Solapamiento Supabase/NestJS** mal delimitado (doble fuente de verdad) | Arquitectura | Inconsistencias/bugs | Frontera estricta: mutaciones sensibles solo NestJS; RLS solo-lectura en tablas críticas |
| R7 | **Merge de invitados** corrompe historial/rating | Datos | Datos inconsistentes | Merge transaccional + recálculo idempotente + `audit_log`; soft state `MERGED` |
| R8 | **QR abusable** (compartir token, unirse a partidos ajenos) | Seguridad | Resultados falsos | Token firmado TTL corto, nonce, un solo match, estado CONSUMED, rate limit |
| R9 | **Generación de pozos/brackets** con casos borde (impares, byes, abandonos) | Lógica | Eventos rotos | Manejo explícito de byes/impares; tests exhaustivos; capacidad de edición manual por admin |
| R10 | **Equipo pequeño (2–3)** abarca demasiado MVP | Entrega | Retrasos/deuda técnica | Secuenciación núcleo→rankings→pozos→torneos; feature flags; diferir matchmaking/americanos a V1 |
| R11 | **Dependencia de proveedores** (Supabase/FCM) | Arquitectura | Lock-in/costos | Lógica de negocio en NestJS (portable); Postgres estándar; abstracción de notificaciones |
| R12 | **Cumplimiento de tiendas** (Apple sign-in, permisos cámara, borrado de cuenta) | Entrega | Rechazo de App Store | Sign in with Apple, textos de permisos, borrado de cuenta desde Sprint 1 |

---

### Módulos/decisiones añadidos respecto al brief original (justificación)

- **Jugadores invitados + merge de identidad** (no estaba explícito): imprescindible para que la red crezca y para que el rating tenga densidad de partidos desde el día 1.
- **Eliminación de Fair Play Score y de roles Organizador/Club/Moderador**: simplificación pedida; reduce superficie de producto y complejidad de permisos sin perder funcionalidad (permisos derivados de rol + propiedad).
- **Vista materializada de rankings y colas para rating**: necesarios para la meta de escala (100k) sin penalizar latencia.
- **Frontera estricta Supabase/NestJS**: evita la trampa común de tener dos backends compitiendo por la verdad.
- **Trust weight por origen de partido** (amistoso vs pozo/torneo): refuerza la integridad del rating, núcleo del producto.
- **Diferir teléfono/matchmaking/americanos a V1**: alinea el alcance con un equipo de 2–3 y el criterio "barato pero bueno, sin deadline".

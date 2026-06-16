# Guía del proyecto — Pádel App

Monorepo: `apps/backend` (NestJS + Prisma), `apps/mobile` (Flutter), `infra/` (docker, Supabase). Ver [PRD_Padel_App.md](PRD_Padel_App.md) y el README.

## Skills de diseño (UI/UX Pro Max) — SOLO para móvil

Las skills instaladas en `.claude/skills/` (`ui-ux-pro-max`, `ui-styling`, `design-system`,
`design`, `brand`, `banner-design`, `slides`) se usan **exclusivamente para la app móvil
Flutter (`apps/mobile`)**: diseño visual, componentes, estilos, paletas, tipografía y UX.

**No** aplicar estas skills al backend (`apps/backend`) ni a infraestructura — ahí no hay UI.
Al construir/ajustar pantallas Flutter, usar el stack **Flutter** de `ui-ux-pro-max`.

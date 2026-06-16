# Imagen de producción del backend NestJS (deploy a staging/prod, PRD §18).
# Build multi-stage: compila con devDeps, ejecuta solo con runtime deps.

FROM node:20-alpine AS builder
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/backend/package.json apps/backend/
RUN pnpm install --frozen-lockfile
COPY apps/backend apps/backend
WORKDIR /app/apps/backend
RUN pnpm exec prisma generate
RUN pnpm build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/backend/package.json apps/backend/
RUN pnpm install --frozen-lockfile --prod
COPY --from=builder /app/apps/backend/dist apps/backend/dist
COPY --from=builder /app/apps/backend/prisma apps/backend/prisma
COPY --from=builder /app/node_modules/.prisma node_modules/.prisma
WORKDIR /app/apps/backend
EXPOSE 3000
# Aplica migraciones pendientes y arranca.
CMD ["sh", "-c", "pnpm exec prisma migrate deploy && node dist/main.js"]

import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';

import { SupabaseJwtGuard } from './supabase-jwt.guard';
import { RolesGuard } from './roles.guard';

/**
 * Registra los guards globales (PRD §16):
 * 1) SupabaseJwtGuard — autenticación (salvo rutas @Public()).
 * 2) RolesGuard — autorización por @Roles().
 * El orden de registro es el orden de ejecución.
 */
@Global()
@Module({
  providers: [
    { provide: APP_GUARD, useClass: SupabaseJwtGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AuthModule {}

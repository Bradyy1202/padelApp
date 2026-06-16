import { SetMetadata, createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Role } from '@prisma/client';

/** Usuario autenticado adjuntado a la request por SupabaseJwtGuard. */
export interface AuthUser {
  id: string; // = auth.users.id (sub del JWT)
  email?: string;
  role?: Role; // cargado por RolesGuard cuando hace falta
}

/** Marca una ruta como pública (sin auth). */
export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

/** Restringe una ruta a ciertos roles (PRD §4). */
export const ROLES_KEY = 'roles';
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);

/** Inyecta el usuario autenticado en un handler: `@CurrentUser() user: AuthUser`. */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthUser => {
    return ctx.switchToHttp().getRequest().user;
  },
);

import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { AuthUser, ROLES_KEY } from './auth.decorators';

/**
 * Autorización por rol (PRD §4, §16). El rol NO viene del JWT: se carga desde
 * `profiles.role` por el userId autenticado, para que sea la fuente de verdad.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const req = context.switchToHttp().getRequest();
    const user = req.user as AuthUser | undefined;
    if (!user?.id) throw new ForbiddenException('No autenticado');

    const profile = await this.prisma.profile.findUnique({ where: { id: user.id } });
    const role = profile?.role ?? Role.jugador;
    user.role = role;

    if (!required.includes(role)) {
      throw new ForbiddenException('Permisos insuficientes');
    }
    return true;
  }
}

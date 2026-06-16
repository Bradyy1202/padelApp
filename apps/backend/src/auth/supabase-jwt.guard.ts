import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { createRemoteJWKSet, jwtVerify, JWTPayload } from 'jose';
import { Request } from 'express';

import { IS_PUBLIC_KEY } from './auth.decorators';

/**
 * Verifica el JWT de Supabase (PRD §16): firma contra el JWKS de Supabase, nunca
 * confía en claims sin verificar. Adjunta `req.user = { id, email }`.
 *
 * Dev: si AUTH_DEV_BYPASS=true (no producción), acepta el header `x-dev-user-id`
 * como usuario sin JWT, para probar endpoints localmente sin proyecto Supabase.
 */
@Injectable()
export class SupabaseJwtGuard implements CanActivate {
  private readonly logger = new Logger(SupabaseJwtGuard.name);
  private jwks?: ReturnType<typeof createRemoteJWKSet>;

  constructor(
    private readonly reflector: Reflector,
    private readonly config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const req = context.switchToHttp().getRequest<Request>();

    // Bypass de desarrollo (gated): solo fuera de producción y con flag explícito.
    const devBypass = this.config.get<string>('AUTH_DEV_BYPASS') === 'true';
    if (devBypass && this.config.get('env') !== 'production') {
      const devUserId = req.header('x-dev-user-id');
      if (devUserId) {
        (req as any).user = { id: devUserId, email: req.header('x-dev-email') };
        return true;
      }
    }

    const token = this.extractBearer(req);
    if (!token) throw new UnauthorizedException('Falta el token Bearer');

    try {
      const payload = await this.verify(token);
      if (!payload.sub) throw new UnauthorizedException('Token sin sub');
      (req as any).user = { id: payload.sub, email: payload.email as string | undefined };
      return true;
    } catch (err) {
      this.logger.warn(`JWT inválido: ${(err as Error).message}`);
      throw new UnauthorizedException('Token inválido o expirado');
    }
  }

  private extractBearer(req: Request): string | undefined {
    const auth = req.header('authorization');
    if (!auth?.startsWith('Bearer ')) return undefined;
    return auth.slice(7);
  }

  private async verify(token: string): Promise<JWTPayload> {
    const jwksUrl = this.config.get<string>('supabase.jwksUrl');
    if (!jwksUrl) {
      throw new Error('SUPABASE_JWKS_URL no configurado');
    }
    if (!this.jwks) {
      this.jwks = createRemoteJWKSet(new URL(jwksUrl));
    }
    const { payload } = await jwtVerify(token, this.jwks);
    return payload;
  }
}

import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SignJWT, jwtVerify } from 'jose';
import { randomUUID, randomInt } from 'crypto';

export interface QrTokenPayload {
  matchId: string;
  nonce: string;
}

/**
 * Token QR firmado para unirse a un partido (PRD §7.3): JWT corto (HS256) con
 * match_id, nonce y exp (TTL configurable, 2h por defecto). Incluye un código
 * corto alfanumérico de respaldo.
 */
@Injectable()
export class QrService {
  private readonly secret: Uint8Array;
  private readonly ttlSeconds: number;

  constructor(config: ConfigService) {
    this.secret = new TextEncoder().encode(config.get<string>('qr.jwtSecret'));
    this.ttlSeconds = config.get<number>('qr.ttlSeconds') ?? 7200;
  }

  get ttl(): number {
    return this.ttlSeconds;
  }

  async sign(matchId: string): Promise<{ token: string; nonce: string; expiresAt: Date }> {
    const nonce = randomUUID();
    const expiresAt = new Date(Date.now() + this.ttlSeconds * 1000);
    const token = await new SignJWT({ matchId, nonce })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
      .sign(this.secret);
    return { token, nonce, expiresAt };
  }

  async verify(token: string): Promise<QrTokenPayload> {
    const { payload } = await jwtVerify(token, this.secret);
    return { matchId: payload.matchId as string, nonce: payload.nonce as string };
  }

  /** Código corto de respaldo (6 caracteres, sin caracteres ambiguos). */
  generateShortCode(): string {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) code += alphabet[randomInt(alphabet.length)];
    return code;
  }
}
